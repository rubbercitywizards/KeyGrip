//
//  RCWKGClientAPI.h
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

#import <Foundation/Foundation.h>
#import "RCWStreamConnection.h"

@class RCWKGClientAPI;

/**
 `RCWKGClientAPIDelegate` defines the callback methods for different events the API receives when talking to the server. They are all required methods because it's a good idea to handle them all. Seriously.
 */
@protocol RCWKGClientAPIDelegate <NSObject>

/// Called when a connection successfully completes with the server.
- (void)clientDidConnect:(RCWKGClientAPI *)client;

/// Called every time the heartbeat ping is received from the server.
- (void)clientReceivedServerPing:(RCWKGClientAPI *)client;

/// Called when the server sends us a new HTML script. Includes the filename that we can display to the user of the client if need be.
- (void)client:(RCWKGClientAPI *)client receivedScript:(NSString *)html named:(NSString *)filename;

/// Called when the server successfully put a clip with the given `textID` into the pastboard of the server's host machine.
- (void)client:(RCWKGClientAPI *)client notifiedOfPastedTextID:(NSString *)textID;

/// Told of an error on server side (like file is not valid format). Not catastrophic to the connection.
- (void)client:(RCWKGClientAPI *)client notifiedOfServerError:(NSError *)error;

/// Client couldn't communicate with server at all. Catastrophic. Connection is terminated.
- (void)client:(RCWKGClientAPI *)client failedWithError:(NSError *)error;

@end

/**
 `RCWKGClientAPI` is an object that handles the asynchronous communication with and callbacks from the `RCWKGServerAPI` on the other end of the connection.
 */
@interface RCWKGClientAPI : NSObject

@property (nonatomic, weak) id<RCWKGClientAPIDelegate> delegate;

/// Initializes the API object with the connection to talk with the server.
- (instancetype)initWithConnection:(id<RCWStreamConnection>)connection;

/// Stops the API client. Kills any existing connection. Can be called multiple times with no ill effects.
- (void)stop;

/// Sends a heartbeat ping to the server. These pings are not required but are a great way to regularly test if the connection is broken or not.
- (void)sendPing;

/// Sends a command to the server to send back the script.
- (void)askServerForScript;

/// Asks the server to put a clip with the given `textID` in the pastboard of the server's host machine.
- (void)pasteTextWithID:(NSString *)textID;

/// Tell the server that something went wrong on the client end.
- (void)notifyServerOfErrorMessage:(NSString *)msg;

@end
