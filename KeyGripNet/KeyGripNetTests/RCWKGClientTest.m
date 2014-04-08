//
//  RCWKGClientTest.m
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

#import <XCTest/XCTest.h>
#import "RCWKGClientAPI.h"
#import "RCWKGServerAPI.h"
#import "TestCaseStreamConnection.h"
#import "RCWKGProtocolCommand.h"

@interface RCWKGClientTest : XCTestCase
<RCWKGServerAPIDelegate, RCWKGClientAPIDelegate>
@property (nonatomic, strong) RCWKGClientAPI *client;
@property (nonatomic, strong) RCWKGServerAPI *server;

@property (nonatomic, strong) NSError *lastClientErrorReceived;
@property (nonatomic, strong) NSError *lastServerErrorReceived;

// Helper properties to assert that commands were received by client
@property (nonatomic) BOOL clientConnected;
@property (nonatomic) BOOL clientReceivedPing;
@property (nonatomic, strong) NSString *clientReceivedTextID;
@property (nonatomic, strong) NSString *clientReceivedHTML;
@property (nonatomic, strong) NSString *clientReceivedScriptName;
@property (nonatomic, strong) NSString *clientToldItemWasPasted;

// Helper properties to assert that comamnds were received by server
@property (nonatomic) BOOL serverConnected;
@property (nonatomic) BOOL serverReceivedPing;
@property (nonatomic) BOOL serverReceivedRequestForScript;
@property (nonatomic) NSString *serverAskedToPasteItem;
@end

@implementation RCWKGClientTest

- (void)setUp
{
    [super setUp];
    TestCaseStreamConnection *clientConnection = [[TestCaseStreamConnection alloc] init];
    TestCaseStreamConnection *serverConnection = [[TestCaseStreamConnection alloc] init];
    clientConnection.otherConnection = serverConnection;
    serverConnection.otherConnection = clientConnection;

    self.client = [[RCWKGClientAPI alloc] initWithConnection:clientConnection];
    self.client.delegate = self;
    self.server = [[RCWKGServerAPI alloc] initWithConnection:serverConnection];
    self.server.delegate = self;

    [clientConnection start];
    [serverConnection start];
}

- (void)tearDown
{
    [super tearDown];
    [self.client stop];
    [self.server stop];
}

- (void)testClientConnected
{
    XCTAssertTrue(self.clientConnected);
}

- (void)testServerConnected
{
    XCTAssertTrue(self.serverConnected);
}

- (void)testServerPing
{
    [self.server sendPing];
    XCTAssertTrue(self.clientReceivedPing);
}

- (void)testClientPing
{
    [self.client sendPing];
    XCTAssertTrue(self.serverReceivedPing);
}

- (void)testAskingServerForScriptItems
{
    [self.client askServerForScript];
    XCTAssertTrue(self.serverReceivedRequestForScript);
}

- (void)testTellingServerToPasteItem
{
    [self.client pasteTextWithID:@"23"];
    XCTAssertEqualObjects(self.serverAskedToPasteItem, @"23");
}

- (void)testClientToldWhichItemWasPasted
{
    [self.server pastedTextWithID:@"24"];
    XCTAssertEqualObjects(self.clientToldItemWasPasted, @"24");
}

- (void)testClientReceivedScriptItems
{
    [self.server sendScriptHTML:@"some html" named:@"script name"];

    XCTAssertEqualObjects(self.clientReceivedHTML, @"some html");
    XCTAssertEqualObjects(self.clientReceivedScriptName, @"script name");
}

- (void)testSendingErrorMessageToServer
{
    [self.client notifyServerOfErrorMessage:@"some message"];
    XCTAssertEqualObjects(self.lastClientErrorReceived.localizedDescription, @"some message");
}

- (void)testSendingErrorMessageToClient
{
    [self.server notifyClientOfErrorMessage:@"other message"];
    XCTAssertEqualObjects(self.lastServerErrorReceived.localizedDescription, @"other message");
}


#pragma mark - Client Delegate

- (void)clientDidConnect:(RCWKGClientAPI *)client
{
    self.clientConnected = YES;
}

- (void)clientReceivedServerPing:(RCWKGClientAPI *)client
{
    self.clientReceivedPing = YES;
}

- (void)client:(RCWKGClientAPI *)client failedWithError:(NSError *)error
{
}

- (void)client:(RCWKGClientAPI *)client notifiedOfServerError:(NSError *)error
{
    self.lastServerErrorReceived = error;
}

- (void)client:(RCWKGClientAPI *)client notifiedOfPastedTextID:(NSString *)textID
{
    self.clientToldItemWasPasted = textID;
}

- (void)client:(RCWKGClientAPI *)client receivedScript:(NSString *)html named:(NSString *)filename
{
    self.clientReceivedHTML = html;
    self.clientReceivedScriptName = filename;
}


#pragma mark - Server Delegate

- (void)serverDidConnect:(RCWKGServerAPI *)server
{
    self.serverConnected = YES;
}

- (void)serverReceivedClientPing:(RCWKGServerAPI *)server
{
    self.serverReceivedPing = YES;
}

- (void)server:(RCWKGServerAPI *)server failedWithError:(NSError *)error
{
}

- (void)server:(RCWKGClientAPI *)server notifiedOfClientError:(NSError *)error
{
    self.lastClientErrorReceived = error;
}

- (void)serverAskedForScript:(RCWKGServerAPI *)server
{
    self.serverReceivedRequestForScript = YES;
}

- (void)server:(RCWKGServerAPI *)server askedToPasteTextWithId:(NSString *)textId
{
    self.serverAskedToPasteItem = textId;
}

@end
