//
//  RCWKGSocketConnectionTest.m
//  KeyGripNet
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
#import "XCTAsyncTestCase.h"
#import "RCWSocketServerConnection.h"
#import "RCWSocketClientConnection.h"

@interface RCWKGSocketConnectionTest : XCTAsyncTestCase
<RCWConnectionDelegate>
@property (nonatomic, strong) RCWSocketServerConnection *serverConnection;
@property (nonatomic, strong) RCWSocketClientConnection *clientConnection;

@property (nonatomic, strong) NSError *lastErrorSeenByClient;
@property (nonatomic, strong) NSError *lastErrorSeenByServer;
@property (nonatomic, strong) NSString *lastStringReceivedByClient;
@property (nonatomic, strong) NSString *lastStringReceivedByServer;
@property (nonatomic) BOOL serverDidConnect, clientDidConnect;
@end

@implementation RCWKGSocketConnectionTest

- (void)setUp
{
    [super setUp];
    self.serverConnection = [[RCWSocketServerConnection alloc] init];
    [self.serverConnection bindToPort:kRCWKGSocketServerConnectionAnyPort];
    self.serverConnection.delegate = self;

    self.clientConnection = [[RCWSocketClientConnection alloc] initClientWithHost:@"127.0.0.1" port:self.serverConnection.port];
    self.clientConnection.delegate = self;
}

- (void)tearDown
{
    [super tearDown];
    [self.clientConnection stop];
    [self.serverConnection stop];
}

- (void)testIntegrationBetweenClientAndServerConnection
{
    [self.serverConnection startListening];
    [self.clientConnection attemptToConnect];

    [self prepare];
    [self.serverConnection sendData:[@"from server" dataUsingEncoding:NSUTF8StringEncoding]];
    [self waitForStatus:kXCTUnitWaitStatusSuccess timeout:10];
    XCTAssertEqualObjects(self.lastStringReceivedByClient, @"from server");

    [self prepare];
    [self.clientConnection sendData:[@"from client" dataUsingEncoding:NSUTF8StringEncoding]];
    [self waitForStatus:kXCTUnitWaitStatusSuccess timeout:10];
    XCTAssertEqualObjects(self.lastStringReceivedByServer, @"from client");

    XCTAssert(self.serverDidConnect);
    XCTAssert(self.clientDidConnect);
}

#pragma mark - Delegate Methods

- (void)connectionDidConnect:(id<RCWStreamConnection>)connection
{
    if (connection == self.clientConnection) {
        self.clientDidConnect = YES;
    } else if (connection == self.serverConnection) {
        self.serverDidConnect = YES;
    }
}

- (void)connection:(id<RCWStreamConnection>)connection failedWith:(NSError *)error
{
    if (connection == self.clientConnection) {
        self.lastErrorSeenByClient = error;
    } else if (connection == self.serverConnection) {
        self.lastErrorSeenByServer = error;
    }
    [self notify:kXCTUnitWaitStatusFailure];
}

- (void)connection:(id<RCWStreamConnection>)connection didReceiveData:(NSData *)data
{
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (connection == self.clientConnection) {
        self.lastStringReceivedByClient = string;
    } else if (connection == self.serverConnection) {
        self.lastStringReceivedByServer = string;
    }
    [self notify:kXCTUnitWaitStatusSuccess];
}

@end
