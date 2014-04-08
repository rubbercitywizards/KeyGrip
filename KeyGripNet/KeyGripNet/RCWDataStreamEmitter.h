//
//  RCWDataStreamEmitter.h
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

/**
 `RCWDataStreamEmitter` acts like a ring buffer to produce frame data according to the KeyGrip protocol. Just pump `NSData` objects into it and read data from it to pump into a socket. It will be properly framed and sits ready to give data when you need it and the socket is free.

 If you dig into this class, you'll see that we instantiate a lot of `NSMutableData` objects to pull this off. Yeah, yeah. It's not the most efficient thing ever. It works and it is fast enough for this very lightweight communication protocol. Make a pull request with a better implementation and tests first before you complain. :)
 */
@interface RCWDataStreamEmitter : NSObject

@property (nonatomic, readonly) BOOL hasData;

- (void)reset;
- (void)emitData:(NSData *)data;
- (NSInteger)attemptToRead:(uint8_t *)buffer maxLength:(NSUInteger)len;
- (void)markActualByteCountRead:(NSUInteger)len;

@end
