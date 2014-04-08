//
//  RCWKGClient.m
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

#import "RCWKGClientAPI.h"
#import "RCWKGProtocolCommand.h"

@interface RCWKGClientAPI ()
<RCWConnectionDelegate>
@property (nonatomic, strong) id<RCWStreamConnection> connection;
@property (nonatomic, strong) NSTimer *heartbeatTimer;
@end

@implementation RCWKGClientAPI

- (instancetype)initWithConnection:(id<RCWStreamConnection>)connection
{
    if (self = [super init]) {
        _connection = connection;
        _connection.delegate = self;
    }
    return self;
}

- (void)stop
{
    [self.heartbeatTimer invalidate];
    self.heartbeatTimer = nil;
    [self.connection stop];
}

- (void)sendPing
{
    RCWKGProtocolCommand *command = [RCWKGProtocolCommand commandWithName:@"ping"];
    [self.connection sendData:[command convertToData]];
}

- (void)askServerForScript
{
    RCWKGProtocolCommand *command = [RCWKGProtocolCommand commandWithName:@"sendScript"];
    [self.connection sendData:[command convertToData]];
}

- (void)pasteTextWithID:(NSString *)textID
{
    RCWKGProtocolCommand *command = [RCWKGProtocolCommand commandWithName:@"pasteText"];
    command.payload = @{@"textID": textID};
    [self.connection sendData:[command convertToData]];
}

- (void)notifyServerOfErrorMessage:(NSString *)msg
{
    RCWKGProtocolCommand *command = [RCWKGProtocolCommand commandWithName:@"error"];
    command.payload = @{@"message": msg};
    [self.connection sendData:[command convertToData]];
}

- (void)connectionDidConnect:(id<RCWStreamConnection>)connection
{
    self.heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(sendPing) userInfo:nil repeats:YES];
    [self.delegate clientDidConnect:self];
}

- (void)connection:(id<RCWStreamConnection>)connection didReceiveData:(NSData *)data
{
    NSError *error = nil;
    RCWKGProtocolCommand *command = [RCWKGProtocolCommand commandFromData:data error:&error];
    if (!command) {
        [self.delegate client:self failedWithError:error];
        return;
    }

    if ([command.commandName isEqualToString:@"ping"]) {
        [self.delegate clientReceivedServerPing:self];
    } else if ([command.commandName isEqualToString:@"pastedText"]) {
        NSString *textID = command.payload[@"textID"];
        [self.delegate client:self notifiedOfPastedTextID:textID];
    } else if ([command.commandName isEqualToString:@"loadScriptHTML"]) {
        NSString *html = command.payload[@"html"];
        NSString *name = command.payload[@"name"];
        [self.delegate client:self receivedScript:html named:name];
    } else if ([command.commandName isEqualToString:@"error"]) {
        NSError *error = [NSError errorWithDomain:@"RCWServerSideError" code:0 userInfo:@{NSLocalizedDescriptionKey: command.payload[@"message"]}];
        [self.delegate client:self notifiedOfServerError:error];
    } else {
        NSLog(@"Unknown command received from server: %@\n\n%@", command.commandName, command.payload);
    }
}

- (void)connection:(id<RCWStreamConnection>)connection failedWith:(NSError *)error
{
    [self stop];
    [self.delegate client:self failedWithError:error];
}

@end
