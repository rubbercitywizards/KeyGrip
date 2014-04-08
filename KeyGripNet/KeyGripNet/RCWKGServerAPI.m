//
//  RCWKGServerAPI.m
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

#import "RCWKGServerAPI.h"
#import "RCWKGProtocolCommand.h"

@interface RCWKGServerAPI ()
<RCWConnectionDelegate>
@property (nonatomic, strong) id<RCWStreamConnection> connection;
@property (nonatomic, strong) NSTimer *heartbeatTimer;
@end

@implementation RCWKGServerAPI

- (instancetype)initWithConnection:(id<RCWStreamConnection>)connection
{
    if (self = [super init]) {
        _connection = connection;
        _connection.delegate = self;
    }
    return self;
}

- (BOOL)isConnected
{
    return self.connection.isConnected;
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

- (void)pastedTextWithID:(NSString *)textID
{
    RCWKGProtocolCommand *command = [RCWKGProtocolCommand commandWithName:@"pastedText"];
    command.payload = @{@"textID": textID};
    [self.connection sendData:[command convertToData]];
}

- (void)sendScriptHTML:(NSString *)html named:(NSString *)name
{
    RCWKGProtocolCommand *command = [RCWKGProtocolCommand commandWithName:@"loadScriptHTML"];
    command.payload = @{@"html": html, @"name": name};
    [self.connection sendData:[command convertToData]];
}

- (void)notifyClientOfErrorMessage:(NSString *)msg
{
    RCWKGProtocolCommand *command = [RCWKGProtocolCommand commandWithName:@"error"];
    command.payload = @{@"message": msg};
    [self.connection sendData:[command convertToData]];
}

- (void)connection:(id<RCWStreamConnection>)connection didReceiveData:(NSData *)data
{
    NSError *error = nil;
    RCWKGProtocolCommand *command = [RCWKGProtocolCommand commandFromData:data error:&error];
    if (!command) {
        [self.delegate server:self failedWithError:error];
        return;
    }

    if ([command.commandName isEqualToString:@"ping"]) {
        [self.delegate serverReceivedClientPing:self];
    } else if ([command.commandName isEqualToString:@"sendScript"]) {
        [self.delegate serverAskedForScript:self];
    } else if ([command.commandName isEqualToString:@"pasteText"]) {
        NSString *textID = command.payload[@"textID"];
        [self.delegate server:self askedToPasteTextWithId:textID];
    } else if ([command.commandName isEqualToString:@"error"]) {
        NSError *error = [NSError errorWithDomain:@"RCWClientSideError" code:0 userInfo:@{NSLocalizedDescriptionKey: command.payload[@"message"]}];
        [self.delegate server:self notifiedOfClientError:error];
    } else {
        NSLog(@"Unknown command received from server: %@\n\n%@", command.commandName, command.payload);
    }
}

- (void)connection:(id<RCWStreamConnection>)connection failedWith:(NSError *)error
{
    [self stop];
    [self.delegate server:self failedWithError:error];
}

- (void)connectionDidConnect:(id<RCWStreamConnection>)connection
{
    self.heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(sendPing) userInfo:nil repeats:YES];
    [self.delegate serverDidConnect:self];
}

@end
