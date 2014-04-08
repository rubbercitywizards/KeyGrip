//
//  RCWDataStreamCollector.h
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

typedef void(^RCWDataStreamCollectorReceivedCallback)(NSData *data);

/**
 `RCWDataStreamCollector` acts like a ring buffer to collect and frame data according to the KeyGrip protocol. Just pump bytes into it from the socket and once a data frame is complete, the collector calls the `callback` block with fully formed data.

 If you dig into this class, you'll see that we instantiate a lot of `NSMutableData` objects to pull this off. Yeah, yeah. It's not the most efficient thing ever. It works and it is fast enough for this very lightweight communication protocol. Make a pull request with a better implementation and tests first before you complain. :)
 */
@interface RCWDataStreamCollector : NSObject

@property (nonatomic, copy) RCWDataStreamCollectorReceivedCallback callback;

- (void)reset;

- (NSInteger)write:(const uint8_t *)buffer length:(NSUInteger)length error:(NSError **)error;

@end


