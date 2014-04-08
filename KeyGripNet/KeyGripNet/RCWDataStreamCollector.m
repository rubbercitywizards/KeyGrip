//
//  RCWDataStreamCollector.m
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

#import "RCWDataStreamCollector.h"

@interface RCWDataStreamCollector ()
@property (nonatomic, strong) NSMutableData *collection;
@property (nonatomic) BOOL needsToCollectLengthPreamble;
@property (nonatomic) NSUInteger expectedDataLength;
@end

@implementation RCWDataStreamCollector

- (instancetype)init
{
    if (self = [super init]) {
        _needsToCollectLengthPreamble = YES;
    }
    return self;
}

- (void)reset
{
    self.needsToCollectLengthPreamble = YES;
    self.expectedDataLength = 0;
    self.collection = nil;
}

- (NSInteger)write:(const uint8_t *)buffer length:(NSUInteger)length error:(NSError **)error
{
    NSAssert(self.callback, @"This object isn't very useful if you don't set a callback.");

    if (length == 0) { return 0; };

    if (self.collection == nil) {
        self.collection = [NSMutableData data];
    }

    [self.collection appendBytes:buffer length:length];

    if (self.needsToCollectLengthPreamble) {
        uint32_t dataLength = 0;
        uint8_t bytesSoFar[30];
        memset(bytesSoFar, 1, 30);
        [self.collection getBytes:bytesSoFar length:MIN(self.collection.length, 30)];
        int position = 0;
        int result = sscanf((char *)bytesSoFar, "%u%n", &dataLength, &position);
        position = (int)MIN(position, self.collection.length);
        if (bytesSoFar[position] == 0 && result == 1) {
            self.needsToCollectLengthPreamble = NO;
            self.expectedDataLength = dataLength;
            int preambleLength = (int)strlen(self.collection.bytes) + 1;
            self.collection = [NSMutableData dataWithBytes:self.collection.bytes + preambleLength
                                                    length:self.collection.length - preambleLength];
        } else if (result != 1) {
            if (error) {
                *error = [NSError errorWithDomain:@"RCWDataStreamCollector" code:0 userInfo:@{NSLocalizedDescriptionKey: @"Could not read length preamble from data packet."}];
            }
            return -1;
        }
    }

    if (!self.needsToCollectLengthPreamble && self.collection.length >= self.expectedDataLength) {
        NSData *output = [NSData dataWithBytes:self.collection.bytes length:self.expectedDataLength];
        self.collection = [NSMutableData dataWithBytes:self.collection.bytes + self.expectedDataLength
                                                length:self.collection.length - self.expectedDataLength];
        self.needsToCollectLengthPreamble = YES;
        self.expectedDataLength = 0;
        self.callback(output);
    }

    return length;
}

@end
