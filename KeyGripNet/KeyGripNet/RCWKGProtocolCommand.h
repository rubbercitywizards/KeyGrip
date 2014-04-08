//
//  RCWKGProtocolCommand.h
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

typedef NS_ENUM(NSInteger, RCWKGProtocolCommandErrorCode) {
    RCWKGProtocolUnrecognized,
    RCWKGProtocolUnparsable,
    RCWKGProtocolMissingMetadata
};

/**
 `RCWKGProtocolCommand` is a simple object to make it easy to send a payload of data with a command name over the wire.
 */
@interface RCWKGProtocolCommand : NSObject

/// Some string to describe the command.
@property (nonatomic, copy) NSString *commandName;
/// Some payload
@property (nonatomic, strong) NSDictionary *payload;

/// Helper method to create a command to send with a given name. Same as initializing a fresh command object and setting the `commandName` property.
+ (instancetype)commandWithName:(NSString *)name;

/// Creates an object with a command name and payload from an `NSData` object.
+ (instancetype)commandFromData:(NSData *)data error:(NSError **)error;

/// Convert the command object to `NSData` for sending.
- (NSData *)convertToData;

@end
