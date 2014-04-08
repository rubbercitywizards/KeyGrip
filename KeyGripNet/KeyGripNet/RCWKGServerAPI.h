//
//  RCWKGServerAPI.h
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

@class RCWKGServerAPI;

/**
 `RCWKGServerAPIDelegate` defines the callback methods for different events the API receives when talking to the client. They are all required methods because it's a good idea to handle them all. Seriously.
 */
@protocol RCWKGServerAPIDelegate <NSObject>

/// Called when a connection successfully completes with the client.
- (void)serverDidConnect:(RCWKGServerAPI *)server;

/// Called every time the heartbeat ping is received from the client.
- (void)serverReceivedClientPing:(RCWKGServerAPI *)server;

/// Called when the client asks us to (re)send the HTML script.
- (void)serverAskedForScript:(RCWKGServerAPI *)server;

/// Called when the client is asking the server to put the text with the given `textID` on the pastboard.
- (void)server:(RCWKGServerAPI *)server askedToPasteTextWithId:(NSString *)textID;

/// Told of an error on client side. Not catastrophic to the connection.
- (void)server:(RCWKGServerAPI *)client notifiedOfClientError:(NSError *)error;

/// Client couldn't communicate with client at all. Catastrophic. Connection terminated.
- (void)server:(RCWKGServerAPI *)server failedWithError:(NSError *)error;

@end

/**
 `RCWKGServerAPI` is an object that handles the asynchronous communication with and callbacks from the `RCWKGClientAPI` on the other end of the connection.
 */
@interface RCWKGServerAPI : NSObject

/// Property that delegates down to the connection object to find out if there is actually a connection.
@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, weak) id<RCWKGServerAPIDelegate> delegate;

/// Initializes the API object with the connection to talk with the server.
- (instancetype)initWithConnection:(id<RCWStreamConnection>)connection;

/// Stops the API server. Kills any existing connection. Can be called multiple times with no ill effects.
- (void)stop;

/// Sends a heartbeat ping to the client. These pings are not required but are a great way to regularly test if the connection is broken or not.
- (void)sendPing;

/// Tells the client that a clip with the given `textID` has been placed on to the pasteboard.
- (void)pastedTextWithID:(NSString *)textID;

/// Sends the given HTML script with the given name to the client.
- (void)sendScriptHTML:(NSString *)html named:(NSString *)name;

/// Tells the client about a problem. The client can then display this to the user if need be.
- (void)notifyClientOfErrorMessage:(NSString *)msg;

@end
