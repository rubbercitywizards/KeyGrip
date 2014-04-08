//
//  RCWKGProtocolCommand.m
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

#import "RCWKGProtocolCommand.h"

@implementation RCWKGProtocolCommand

+ (instancetype)commandWithName:(NSString *)name
{
    RCWKGProtocolCommand *command = [[self alloc] init];
    command.commandName = name;
    return command;
}

+ (instancetype)commandFromData:(NSData *)data error:(NSError *__autoreleasing *)error
{
    NSDictionary *dict = nil;
    @try {
        dict = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        if (![dict isKindOfClass:[NSDictionary class]]) {
            if (error) {
                *error = [NSError errorWithDomain:@"RCWKGProtocolCommand" code:RCWKGProtocolUnrecognized userInfo:@{NSLocalizedDescriptionKey:@"Unrecognized data format."}];
            }
            return nil;
        }
    }
    @catch (NSException *exception) {
        if ([exception.name isEqualToString:NSInvalidArgumentException]) {
            if (error) {
                *error = [NSError errorWithDomain:@"RCWKGProtocolCommand" code:RCWKGProtocolUnparsable userInfo:@{NSLocalizedDescriptionKey:@"Unparsable data format."}];
            }
            return nil;
        }
        @throw exception;
    }

    RCWKGProtocolCommand *command = [[self alloc] init];

    command.commandName = dict[@"_command"];
    if (!command.commandName || ![command.commandName isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@"RCWKGProtocolCommand" code:RCWKGProtocolMissingMetadata userInfo:@{NSLocalizedDescriptionKey:@"Missing command metadata."}];
        }
        return nil;
    }
    command.payload = dict[@"_payload"];
    return command;
}

- (NSData *)convertToData
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"_command"] = self.commandName;
    if (self.payload) {
        dict[@"_payload"] = self.payload;
    }
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:dict];
    return data;
}

@end
