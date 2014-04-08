//
//  RCWKGProtocolCommandTest.m
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
#import "RCWKGProtocolCommand.h"

@interface RCWKGProtocolCommandTest : XCTestCase

@end

@implementation RCWKGProtocolCommandTest

- (void)testConvertingToAndFromData
{
    RCWKGProtocolCommand *command = [RCWKGProtocolCommand commandWithName:@"something"];

    NSData *data = [command convertToData];

    NSError *error = nil;
    RCWKGProtocolCommand *command2 = [RCWKGProtocolCommand commandFromData:data error:&error];
    XCTAssert(command2);
    XCTAssertNil(error);
    XCTAssertEqualObjects(command2.commandName, @"something");
}

- (void)testLoadingBadData
{
    NSData *data = [@"bad data" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    XCTAssertNil([RCWKGProtocolCommand commandFromData:data error:&error]);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Unparsable data format.", error.localizedDescription);
    XCTAssertEqual(error.code, RCWKGProtocolUnparsable);
}

- (void)testImportingWrongType
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:@[@1]];
    NSError *error = nil;
    XCTAssertNil([RCWKGProtocolCommand commandFromData:data error:&error]);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Unrecognized data format.", error.localizedDescription);
    XCTAssertEqual(error.code, RCWKGProtocolUnrecognized);
}

- (void)testImportingDictionaryWithoutCommandMetadata
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:@{}];
    NSError *error = nil;
    XCTAssertNil([RCWKGProtocolCommand commandFromData:data error:&error]);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Missing command metadata.", error.localizedDescription);
    XCTAssertEqual(error.code, RCWKGProtocolMissingMetadata);
}

@end
