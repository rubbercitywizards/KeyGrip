//
//  RCWKGConnectionTest.m
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
#import "RCWBonjourConnection.h"

@interface RCWKGConnectionTest : XCTAsyncTestCase
<RCWConnectionDelegate>
@property (nonatomic, strong) RCWBonjourConnection *serverConnection;
@property (nonatomic, strong) RCWBonjourConnection *clientConnection;

@property (nonatomic, strong) NSError *lastErrorSeenByClient;
@property (nonatomic, strong) NSError *lastErrorSeenByServer;
@property (nonatomic, strong) NSString *lastStringReceivedByClient;
@property (nonatomic, strong) NSString *lastStringReceivedByServer;
@end

@implementation RCWKGConnectionTest

- (void)setUp
{
    [super setUp];
    self.serverConnection = [[RCWBonjourConnection alloc] initWithIdentifier:@"connectionIntegrationTest"];
    self.serverConnection.delegate = self;
    self.clientConnection = [[RCWBonjourConnection alloc] initWithIdentifier:@"connectionIntegrationTest"];
    self.clientConnection.delegate = self;
}

- (void)testIntegrationBetweenClientAndServerConnection
{
    [self.serverConnection shareConnection];
    [self.clientConnection findConnection];

    [self prepare];
    [self.serverConnection sendData:[@"from server" dataUsingEncoding:NSUTF8StringEncoding]];
    [self waitForStatus:kXCTUnitWaitStatusSuccess timeout:10];
    XCTAssertEqualObjects(self.lastStringReceivedByClient, @"from server");

    [self prepare];
    [self.clientConnection sendData:[@"from client" dataUsingEncoding:NSUTF8StringEncoding]];
    [self waitForStatus:kXCTUnitWaitStatusSuccess timeout:10];
    XCTAssertEqualObjects(self.lastStringReceivedByServer, @"from client");
}

#pragma mark - Delegate Methods

- (void)connectionDidConnect:(RCWBonjourConnection *)connection
{
    // noop
}

- (void)connection:(RCWBonjourConnection *)connection failedWith:(NSError *)error
{
    if (connection == self.clientConnection) {
        self.lastErrorSeenByClient = error;
    } else if (connection == self.serverConnection) {
        self.lastErrorSeenByServer = error;
    }
    [self notify:kXCTUnitWaitStatusFailure];
}

- (void)connection:(RCWBonjourConnection *)connection didReceiveData:(NSData *)data
{
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (connection == self.clientConnection) {
        self.lastStringReceivedByClient = string;
    } else if (connection == self.serverConnection) {
        self.lastStringReceivedByServer = string;
    }
    [self notify:kXCTUnitWaitStatusSuccess];
}

// test that connections can't find each other with different identifiers
// test that connections find each other even with other connections open

@end
