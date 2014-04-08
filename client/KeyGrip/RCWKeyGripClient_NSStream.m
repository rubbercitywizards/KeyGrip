//
//  RCWNetClient.m
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

#import "RCWKeyGripClient.h"
#import "NSStream+RCWAdditions.h"
#import "RCWKeyGripClientCommands.h"

@interface RCWKeyGripClient ()
<NSStreamDelegate, RCWKGClientCommandDelegate>

@property (nonatomic, strong) NSObject *config;
@property (nonatomic, strong) RCWKGClientCommand *executingCommand;

@property (nonatomic, readonly) NSString *host;
@property (nonatomic, readonly) NSString *port;
@property (nonatomic, readonly) NSString *accessKey;

@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;

@property (nonatomic, strong) NSTimer *timeoutTimer;

@end

@implementation RCWKeyGripClient

- (instancetype)initWithConfig:(id<NSObject>)configObject {
    if (self = [super init]) {
        self.config = configObject;
        self.timeout = 2;
    }

    return self;
}

- (instancetype)init {
    if (self = [self initWithConfig:[NSUserDefaults standardUserDefaults]]) {
        self.config = [NSUserDefaults standardUserDefaults];
    }

    return self;
}

- (void)cancel
{
    [self reset];
}

- (void)reset {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;
    self.executingCommand = nil;
    [self.inputStream close];
    [self.outputStream close];
    self.inputStream = nil;
    self.outputStream = nil;
}

- (NSString *)host
{
    return [self.config valueForKey:@"host"];
}

- (NSString *)port
{
    return [self.config valueForKey:@"port"];
}

- (NSString *)accessKey
{
    return [self.config valueForKey:@"accessKey"];
}

- (void)setUpStreams {
    NSInputStream *inputStream = nil;
    NSOutputStream *outputStream = nil;
    [NSStream rcw_getStreamsToHostNamed:self.host port:(UInt32)self.port.integerValue inputStream:&inputStream outputStream:&outputStream];

    self.inputStream = inputStream;
    self.outputStream = outputStream;

    [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

    self.inputStream.delegate = self;
    self.outputStream.delegate = self;

    [self.inputStream open];
    [self.outputStream open];
}

- (void)getStatus:(RCWKGStatusResponse)completion {
    RCWKGClientStatusCommand *command = [[RCWKGClientStatusCommand alloc] init];
    command.completion = completion;
    command.delegate = self;
    self.executingCommand = command;
    [self sendServerCommand:@"status\n"];
}

- (void)getItems:(RCWKGGetResponse)completion {
    RCWKGClientGetCommand *command = [[RCWKGClientGetCommand alloc] init];
    command.completion = completion;
    command.delegate = self;
    self.executingCommand = command;
    [self sendServerCommand:@"get\n"];
}

- (void)commandComplete:(RCWKGClientCommand *)command {
    [self reset];
}

- (void)command:(RCWKGClientCommand *)command failedWithError:(NSError *)error {
    NSLog(@"command failed with error %@", error);
    [self reset];
}

- (void)sendServerCommand:(NSString *)command {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

    [self setUpStreams];

    [self.outputStream write:(const void *)[command UTF8String] maxLength:[command lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];

    [self cueTimeoutTimer];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    if (self.inputStream == aStream) {
        if (eventCode & NSStreamEventHasBytesAvailable) {
            NSUInteger buflen = 8192;
            uint8_t *buffer = calloc(buflen, 1);
            if (buffer == NULL) {
                NSError *error = [NSError errorWithDomain:@"KeyGrip" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Could not allocate buffer for network."}];
                [self.executingCommand handleError:error];
            } else {
                NSInteger count = [self.inputStream read:buffer maxLength:buflen];
                NSData *data = [NSData dataWithBytes:buffer length:count];
                [self.executingCommand handleNewData:data];
                free(buffer);
            }
        }
    }
}

- (void)cueTimeoutTimer {
    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;
    self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:self.timeout target:self.executingCommand selector:@selector(timedOut) userInfo:nil repeats:NO];
}

@end

