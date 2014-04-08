//
//  RCWKGDataStreamCollectorEmitterTest.m
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
#import "RCWDataStreamEmitter.h"
#import "RCWDataStreamCollector.h"

@interface RCWKGDataStreamCollectorEmitterTest : XCTestCase
@property (nonatomic, strong) RCWDataStreamEmitter *emitter;
@property (nonatomic, strong) RCWDataStreamCollector *collector;
@end

@implementation RCWKGDataStreamCollectorEmitterTest

- (void)setUp
{
    [super setUp];
    self.emitter = [[RCWDataStreamEmitter alloc] init];
    self.collector = [[RCWDataStreamCollector alloc] init];
}

- (void)testEmittingDataWithLengthPreamble
{
    NSData *data = [@"get me?" dataUsingEncoding:NSUTF8StringEncoding];
    [self.emitter emitData:data];

    uint8_t buffer[200];
    memset(buffer, 0, 200);

    NSInteger count = [self.emitter attemptToRead:buffer maxLength:200];
    [self.emitter markActualByteCountRead:count];
    XCTAssertEqual(count, (NSInteger)9);
    XCTAssertEqual(0, strcmp("7", (char *)buffer));
    XCTAssertEqual(0, strcmp("get me?", (char *)buffer + 2));
}

- (void)testEmittingLargeDataWithLengthPreamble
{
    NSMutableString *str = [NSMutableString string];
    for (int i = 0; i < 10000; i++) {
        if (arc4random_uniform(1)) {
            [str appendString:@"a"];
        } else {
            [str appendString:@"b"];
        }
    }
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];

    [self.emitter emitData:data];

    char buffer[10];
    memset(buffer, 0, 10);

    NSInteger count = [self.emitter attemptToRead:(uint8_t *)buffer maxLength:6];
    [self.emitter markActualByteCountRead:count];
    XCTAssertEqual(count, 6);
    XCTAssertEqual(buffer[5], 0);
    XCTAssertEqual(0, strcmp("10000", buffer));

    NSMutableData *outputData = [NSMutableData data];
    size_t const bufsize = 97;
    uint8_t readBuffer[bufsize];
    NSInteger readCount = 0;

    do {
        memset(readBuffer, 0, bufsize);
        readCount = [self.emitter attemptToRead:readBuffer maxLength:bufsize];
        [outputData appendBytes:readBuffer length:readCount];
        [self.emitter markActualByteCountRead:readCount];
    } while (readCount > 0);

    NSString *output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(str, output);
}

- (void)testCollectingAnObject
{
    NSData *data = [@"round the rock" dataUsingEncoding:NSUTF8StringEncoding];
    [self.emitter emitData:data];

    uint8_t buffer[50];
    memset(buffer, 0, 50);

    __block NSString *output = nil;
    self.collector.callback = ^(NSData *data) {
        output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    };
    NSError *error = nil;
    NSInteger count = [self.emitter attemptToRead:buffer maxLength:50];
    [self.emitter markActualByteCountRead:count];
    XCTAssertEqual(count, [self.collector write:buffer length:count error:&error]);
    XCTAssertNil(error);
    XCTAssertEqualObjects(output, @"round the rock");
}

- (void)testCollectingAnObjectOverTime
{
    NSData *data = [@"round the rock and stuff" dataUsingEncoding:NSUTF8StringEncoding];
    [self.emitter emitData:data];

    // Keep this *really* short so we're also testing the preamble collection code
    size_t const readEachLoop = 1;
    uint8_t buffer[readEachLoop];

    __block NSString *output = nil;
    self.collector.callback = ^(NSData *data) {
        output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    };

    NSInteger count = 0;
    do {
        NSError *error = nil;
        memset(buffer, 0, readEachLoop);
        count = [self.emitter attemptToRead:buffer maxLength:readEachLoop];
        [self.emitter markActualByteCountRead:count];
        XCTAssertEqual(count, [self.collector write:buffer length:count error:&error]);
        XCTAssertNil(error);
    } while (count > 0);

    XCTAssertEqualObjects(output, @"round the rock and stuff");
}

- (void)testCollectingTwoObjectsAtOnce
{
    NSData *obj1 = [@"object 1" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *obj2 = [@"object 2" dataUsingEncoding:NSUTF8StringEncoding];

    [self.emitter emitData:obj1];
    [self.emitter emitData:obj2];

    // Keep this *really* short so we're also testing the preamble collection code
    size_t const readEachLoop = 1;
    uint8_t buffer[readEachLoop];

    NSMutableArray *collectedOutput = [NSMutableArray array];
    self.collector.callback = ^(NSData *data) {
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [collectedOutput addObject:output];
    };

    NSInteger count = 0;
    do {
        NSError *error = nil;
        memset(buffer, 0, readEachLoop);
        count = [self.emitter attemptToRead:buffer maxLength:readEachLoop];
        NSInteger count = [self.emitter attemptToRead:buffer maxLength:readEachLoop];
        [self.emitter markActualByteCountRead:count];
        XCTAssertEqual(count, [self.collector write:buffer length:count error:&error]);
        XCTAssertNil(error);
    } while (count > 0);

    XCTAssertEqualObjects(collectedOutput[0], @"object 1");
    XCTAssertEqualObjects(collectedOutput[1], @"object 2");
}

- (void)testWithInvalidPreamble
{
    __block BOOL called = NO;
    self.collector.callback = ^(NSData *data) {
        called = YES;
    };

    NSError *error = nil;
    [self.collector write:(uint8_t *)"abc" length:4 error:&error];

    XCTAssertNotNil(error);
    XCTAssertEqualObjects(@"Could not read length preamble from data packet.", error.localizedDescription);

    XCTAssertFalse(called, @"Should never call back.");
}

@end
