//
//  RCWDataStreamEmitter.m
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

#import "RCWDataStreamEmitter.h"

@interface RCWDataStreamEmitter ()
@property (nonatomic, strong) NSMutableData *dataQueue;
@end

@implementation RCWDataStreamEmitter

- (instancetype)init
{
    if (self = [super init]) {
        _dataQueue = [NSMutableData data];
    }
    return self;
}

- (void)reset
{
    self.dataQueue = [NSMutableData data];
}

- (BOOL)hasData
{
    return self.dataQueue.length > 0;
}

- (void)emitData:(NSData *)data
{
    size_t headerLength = 100;
    char lengthString[headerLength];
    memset(lengthString, 0, sizeof(uint8_t) * headerLength);
    sprintf(lengthString, "%lu", (unsigned long)data.length);
    [self.dataQueue appendBytes:lengthString length:strlen(lengthString)+1];
    [self.dataQueue appendData:data];
}

- (NSInteger)attemptToRead:(uint8_t *)buffer maxLength:(NSUInteger)len
{
    if (!self.hasData) return 0;

    NSInteger amountToRead = MIN(self.dataQueue.length, len);

    [self.dataQueue getBytes:buffer length:amountToRead];
    return amountToRead;
}

- (void)markActualByteCountRead:(NSUInteger)len
{
    self.dataQueue = [NSMutableData dataWithBytes:self.dataQueue.bytes + len
                                           length:self.dataQueue.length - len];
}

@end
