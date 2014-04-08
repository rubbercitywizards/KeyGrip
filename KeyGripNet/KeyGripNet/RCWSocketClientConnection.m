//
//  RCWSocketClientConnection.m
//
// KeyGrip - Remote pasteboard and presentation note tool
// Copyright (C) 2014 Rubber City Wizards, Ltd.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "RCWSocketClientConnection.h"
#import "RCWDataStreamCollector.h"
#import "RCWDataStreamEmitter.h"

@interface RCWSocketClientConnection ()
<NSStreamDelegate>

@property (nonatomic, strong) RCWDataStreamEmitter *emitter;
@property (nonatomic, strong) RCWDataStreamCollector *collector;

@property (nonatomic, readwrite, strong) NSString *host;
@property (nonatomic, readwrite, assign) NSUInteger port;
@property (nonatomic, readwrite, assign) BOOL isConnected;

@property (nonatomic, strong) NSInputStream *input;
@property (nonatomic, strong) NSOutputStream *output;

@property (nonatomic) BOOL inputStreamOpen, outputStreamOpen;

@property (nonatomic, strong) NSError *lastInputError, *lastOutputError;
@end

@implementation RCWSocketClientConnection
@synthesize delegate=_delegate;
@synthesize host=_host;
@synthesize port=_port;

- (instancetype)initClientWithHost:(NSString *)host port:(NSUInteger)port
{
    if (self = [self init]) {
        _host = [host copy];
        _port = port;
    }
    return self;
}

- (id)init
{
    if (self = [super init]) {
        _emitter = [[RCWDataStreamEmitter alloc] init];
        _collector = [[RCWDataStreamCollector alloc] init];

        __weak typeof(self) weakSelf = self;
        _collector.callback = ^(NSData *data) {
            [weakSelf.delegate connection:weakSelf didReceiveData:data];
        };
    }
    return self;
}

- (void)dealloc
{
    [self stop];
}

- (void)attemptToConnect
{
    NSInputStream *i = nil;
    NSOutputStream *o = nil;

    [self getStreamsToHostNamed:self.host port:self.port inputStream:&i outputStream:&o];

    NSAssert(i && o, @"Unable to open connection. FIX THIS! TODO");

    self.input = i;
    self.output = o;

    self.input.delegate = self;
    self.output.delegate = self;

    [self.input scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [self.output scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];

    [self.input open];
    [self.output open];
}

- (void)stop
{
    self.input.delegate = nil;
    self.output.delegate = nil;
    [self.input close];
    [self.output close];
    self.input = nil;
    self.output = nil;

    self.isConnected = NO;

    [self.emitter reset];
    [self.collector reset];
}

- (void)sendData:(NSData *)data
{
    [self.emitter emitData:data];
    [self writePendingBytesToOutputStream:self.output];
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            if (self.input == aStream) {
                self.inputStreamOpen = YES;
            } else if (self.output == aStream) {
                self.outputStreamOpen = YES;
            }
            if (self.inputStreamOpen && self.outputStreamOpen && !self.isConnected) {
                self.isConnected = YES;
                [self.delegate connectionDidConnect:self];
            }
            break;

        case NSStreamEventErrorOccurred: {
            if (aStream == self.input) {
                self.lastInputError = aStream.streamError;
            } else {
                self.lastOutputError = aStream.streamError;
            }
            [self stop];
            [self.delegate connection:self failedWith:aStream.streamError];
            break;
        }

        case NSStreamEventEndEncountered: {
            [self stop];
            NSError *error = [NSError errorWithDomain:@"RCWSocketServerDomain" code:2 userInfo:@{NSLocalizedDescriptionKey: @"End of stream encountered."}];
            [self.delegate connection:self failedWith:error];
            break;
        }

        case NSStreamEventHasBytesAvailable:
            [self readBytesFromInputStream:(NSInputStream *)aStream];
            break;

        case NSStreamEventHasSpaceAvailable:
            [self writePendingBytesToOutputStream:(NSOutputStream *)aStream];
            break;

        case NSStreamEventNone:
            break;
    }
}

- (void)readBytesFromInputStream:(NSInputStream *)stream
{
    if (!stream.hasBytesAvailable) { return; }

    size_t bufferSize = 4096;
    uint8_t buffer[bufferSize];

    while (stream.hasBytesAvailable) {
        memset(buffer, 0, sizeof(uint8_t) * bufferSize);
        NSInteger bytesRead = [stream read:buffer maxLength:bufferSize];
        if (bytesRead < 0) {
            [self stop];
            NSError *error = [NSError errorWithDomain:@"RCWSocketServerDomain" code:0 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not read bytes from stream. %ld", (long)bytesRead]}];
            [self.delegate connection:self failedWith:error];
            return;
        }

        NSError *error = nil;
        if ([self.collector write:buffer length:bytesRead error:&error] == -1) {
            [self stop];
            [self.delegate connection:self failedWith:error];
            return;
        }
    }
}

- (void)writePendingBytesToOutputStream:(NSOutputStream *)stream
{
    size_t const bufferSize = 4096;
    uint8_t buffer[bufferSize];

    while (stream.hasSpaceAvailable && self.emitter.hasData) {
        memset(buffer, 0, sizeof(uint8_t) * bufferSize);

        NSUInteger count = [self.emitter attemptToRead:buffer maxLength:bufferSize];
        NSUInteger bytesWritten = [stream write:buffer maxLength:count];
        [self.emitter markActualByteCountRead:bytesWritten];
    }
}

// https://developer.apple.com/library/ios/qa/qa1652/_index.html
- (void)getStreamsToHostNamed:(NSString *)hostName
                         port:(NSUInteger)port
                  inputStream:(out NSInputStream **)inputStreamPtr
                 outputStream:(out NSOutputStream **)outputStreamPtr
{
    CFReadStreamRef     readStream;
    CFWriteStreamRef    writeStream;

    if (hostName == nil) return;
    if ((port <= 0) || (port > 65535)) return;
    assert( (inputStreamPtr != NULL) || (outputStreamPtr != NULL) );

    readStream = NULL;
    writeStream = NULL;

    CFStreamCreatePairWithSocketToHost(
                                       NULL,
                                       (__bridge CFStringRef) hostName,
                                       (UInt32)port,
                                       ((inputStreamPtr  != NULL) ? &readStream : NULL),
                                       ((outputStreamPtr != NULL) ? &writeStream : NULL)
                                       );

    if (inputStreamPtr != NULL) {
        *inputStreamPtr  = CFBridgingRelease(readStream);
    }
    if (outputStreamPtr != NULL) {
        *outputStreamPtr = CFBridgingRelease(writeStream);
    }
}

@end
