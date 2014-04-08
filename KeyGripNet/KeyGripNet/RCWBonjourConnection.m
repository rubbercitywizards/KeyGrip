//
//  RCWBonjourConnection.m
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

#import <sys/socket.h>
#import "RCWBonjourConnection.h"
#import "RCWBonjourConnectionFinder.h"
#import "RCWDataStreamCollector.h"
#import "RCWDataStreamEmitter.h"

NSString * const RCWBonjourConnectionErrorDomain = @"RCWBonjourConnectionErrorDomain";

@interface RCWBonjourConnection ()
<NSStreamDelegate, RCWBonjourConnectionFinderDelegate>

@property (nonatomic, readwrite) BOOL isConnected;
@property (nonatomic, strong) RCWBonjourConnectionFinder *finder;

@property (nonatomic, strong) NSInputStream *input;
@property (nonatomic, strong) NSOutputStream *output;
@property (nonatomic) BOOL inputStreamOpen, outputStreamOpen;

@property (nonatomic, strong) RCWDataStreamEmitter *emitter;
@property (nonatomic, strong) RCWDataStreamCollector *collector;

@end

@implementation RCWBonjourConnection

@synthesize identifier=_identifier;
@synthesize delegate=_delegate;
@synthesize lastInputError=_lastInputError;
@synthesize lastOutputError=_lastOutputError;

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    NSAssert(identifier, @"An identifier to identify this connection must be set!");
    if (self = [super init]) {
        _identifier = identifier;
        _emitter = [[RCWDataStreamEmitter alloc] init];
        _collector = [[RCWDataStreamCollector alloc] init];

        __weak typeof(self) weakSelf = self;
        _collector.callback = ^(NSData *data) {
            [weakSelf.delegate connection:weakSelf didReceiveData:data];
        };
    }
    return self;
}

- (id)init
{
    NSAssert(false, @"Use initWithIdentifier:");
    return nil;
}

- (void)dealloc
{
    [self reset];
}

- (void)shareConnection
{
    [self.finder startBroadcasting];
}

- (void)findConnection
{
    [self.finder startListening];
}

- (void)finder:(RCWBonjourConnectionFinder *)finder connectedWithInput:(NSInputStream *)input output:(NSOutputStream *)output
{
    self.input = input;
    self.output = output;

    self.input.delegate = self;
    self.output.delegate = self;

    [self.input scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.output scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

    [self.input open];
    [self.output open];
}

- (void)finder:(RCWBonjourConnectionFinder *)finder didError:(NSError *)error
{
    [self stop];
    [self.delegate connection:self failedWith:error];
}

- (void)sendData:(NSData *)data
{
    [self.emitter emitData:data];
    [self writePendingBytesToOutputStream:self.output];
}

- (void)stop
{
    [self reset];
}

- (void)reset
{
    self.isConnected = NO;

    self.input.delegate = nil;
    self.output.delegate = nil;
    [self.input close];
    [self.output close];
    self.input = nil;
    self.output = nil;

    [_finder stop];
    self.finder = nil;

    [self.emitter reset];
    [self.collector reset];
}

#pragma mark - Lazy Properties

- (RCWBonjourConnectionFinder *)finder
{
    if (!_finder) {
        _finder = [[RCWBonjourConnectionFinder alloc] initWithIdentifier:self.identifier];
        _finder.delegate = self;
        _finder.debugLogging = YES;
    }
    return _finder;
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
            [self reset];
            [self.delegate connection:self failedWith:aStream.streamError];
            break;
        }

        case NSStreamEventEndEncountered: {
            [self reset];
            NSError *error = [NSError errorWithDomain:RCWBonjourConnectionErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"End of stream encountered."}];
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

    size_t const bufferSize = 4096;
    uint8_t buffer[bufferSize];

    while (stream.hasBytesAvailable) {
        memset(buffer, 0, sizeof(uint8_t) * bufferSize);
        NSInteger bytesRead = [stream read:buffer maxLength:bufferSize];
        if (bytesRead < 0) {
            [self reset];
            NSError *error = [NSError errorWithDomain:RCWBonjourConnectionErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not read bytes from stream. %ld", (long)bytesRead]}];
            [self.delegate connection:self failedWith:error];
            return;
        }

        NSError *error = nil;
        if ([self.collector write:buffer length:bytesRead error:&error] == -1) {
            [self reset];
            [self.delegate connection:self failedWith:error];
            return;
        }
    }
}

- (void)writePendingBytesToOutputStream:(NSOutputStream *)stream
{
    size_t bufferSize = 4096;
    uint8_t buffer[bufferSize];

    while (stream.hasSpaceAvailable && self.emitter.hasData) {
        memset(buffer, 0, sizeof(uint8_t) * bufferSize);

        NSUInteger count = [self.emitter attemptToRead:buffer maxLength:bufferSize];
        NSUInteger bytesWritten = [stream write:buffer maxLength:count];
        [self.emitter markActualByteCountRead:bytesWritten];
    }
}

@end
