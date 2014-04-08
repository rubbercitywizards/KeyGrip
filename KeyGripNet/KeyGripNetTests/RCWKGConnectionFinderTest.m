//
//  RCWKGConnectionFinderTest.m
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
#import "RCWBonjourConnectionFinder.h"

// Declare allegiance to this property here for a test
@interface RCWBonjourConnectionFinder () <NSNetServiceDelegate, RCWBonjourConnectionFinderDelegate>
@end

@interface RCWKGConnectionFinderTest : XCTAsyncTestCase
<RCWBonjourConnectionFinderDelegate>
@property (nonatomic, strong) NSError *lastErrorSeen;

@property (nonatomic, strong) NSInputStream *inputFound;
@property (nonatomic, strong) NSOutputStream *outputFound;
@end

@implementation RCWKGConnectionFinderTest

- (void)testListeningOverNetServices
{
    [self prepare];

    RCWBonjourConnectionFinder *broadcaster = [[RCWBonjourConnectionFinder alloc] initWithIdentifier:@"listenTest"];
    RCWBonjourConnectionFinder *listener = [[RCWBonjourConnectionFinder alloc] initWithIdentifier:@"listenTest"];
    listener.delegate = self;

    [broadcaster startBroadcasting];
    [listener startListening];

    [self waitForStatus:kXCTUnitWaitStatusSuccess timeout:3];

    XCTAssertNil(self.lastErrorSeen);
    XCTAssertNotNil(self.inputFound);
    XCTAssertNotNil(self.outputFound);
}

- (void)testMustHaveSameIdentifier
{
    [self prepare];

    RCWBonjourConnectionFinder *broadcaster = [[RCWBonjourConnectionFinder alloc] initWithIdentifier:@"one"];
    RCWBonjourConnectionFinder *listener = [[RCWBonjourConnectionFinder alloc] initWithIdentifier:@"two"];
    listener.delegate = self;

    [broadcaster startBroadcasting];
    [listener startListening];

    [self waitForTimeout:3];

    XCTAssertNil(self.lastErrorSeen);
    XCTAssertNil(self.inputFound);
    XCTAssertNil(self.outputFound);
}

- (void)testFailureToPublish
{
    [self prepare];

    RCWBonjourConnectionFinder *finder = [[RCWBonjourConnectionFinder alloc] initWithIdentifier:@"listenTest"];
    finder.delegate = self;
    [finder startBroadcasting];

    NSNetService *service = [[NSNetService alloc] initWithDomain:@"domain" type:@"type" name:@"name" port:1];
    [finder netService:service
         didNotPublish:@{NSNetServicesErrorCode: @(1234),
                         NSNetServicesErrorDomain: @"some domain"}];

    [self waitForStatus:kXCTUnitWaitStatusFailure timeout:1];

    XCTAssertNil(self.inputFound);
    XCTAssertNil(self.outputFound);
    XCTAssertEqual(self.lastErrorSeen.code, 1234);
    XCTAssertEqualObjects(self.lastErrorSeen.domain, @"some domain");
}


#pragma mark - RCWBonjourConnectionFinderDelegate methods

- (void)finder:(RCWBonjourConnectionFinder *)finder connectedWithInput:(NSInputStream *)input output:(NSOutputStream *)output
{
    self.inputFound = input;
    self.outputFound = output;
    [self notify:kXCTUnitWaitStatusSuccess];
}

- (void)finder:(RCWBonjourConnectionFinder *)finder didError:(NSError *)error
{
    self.lastErrorSeen = error;
    [self notify:kXCTUnitWaitStatusFailure];
}

@end
