//
//  RCWBonjourConnectionFinder.h
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

@class RCWBonjourConnectionFinder;

@protocol RCWBonjourConnectionFinderDelegate <NSObject>
- (void)finder:(RCWBonjourConnectionFinder *)finder connectedWithInput:(NSInputStream *)input output:(NSOutputStream *)output;
- (void)finder:(RCWBonjourConnectionFinder *)finder didError:(NSError *)error;
@end

@interface RCWBonjourConnectionFinder : NSObject

- (instancetype)initWithIdentifier:(NSString *)identifier;

@property (atomic) BOOL debugLogging;
@property (atomic) NSString *identifier;
@property (atomic, weak) id<RCWBonjourConnectionFinderDelegate> delegate;

/// Starts broadcasting the net service and looking for clients
- (void)startBroadcasting;

/// Starts listening for broadcasting servers.
- (void)startListening;

/// Stops everything, either listening or publishing.
- (void)stop;

@end
