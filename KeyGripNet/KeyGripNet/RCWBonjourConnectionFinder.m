//
//  RCWBonjourConnectionFinder.m
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

#import "RCWBonjourConnectionFinder.h"

NSString * const RCWBonjourConnectionFinderErrorDomain = @"RCWBonjourConnectionFinderErrorDomain";

@interface RCWBonjourConnectionFinder ()
<NSNetServiceDelegate, NSNetServiceBrowserDelegate>

@property (atomic, strong) NSNetService *broadcastingService;
@property (atomic, strong) NSNetServiceBrowser *listeningService;

/// Need to keep a record of services as we see them so we can resolve them.
@property (atomic, strong) NSMutableArray *peerServices;

/// Is this connection listening or broadcasting.
@property (atomic) BOOL isBroadcasting;
/// Set when the object is listening or broadcasting. It can't be switched to something else, and this flag helps guard that.
@property (atomic) BOOL inUse;

@end

@implementation RCWBonjourConnectionFinder

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    NSAssert(identifier, @"A name to identify this connection must be set!");
    if (self = [super init]) {
        _peerServices = [NSMutableArray array];
        _identifier = identifier;
    }
    return self;
}

- (id)init
{
    NSAssert(false, @"Must use initWithIdentifier:");
    return nil;
}

- (void)dealloc
{
    self.broadcastingService.delegate = nil;
    self.listeningService.delegate = nil;
}

- (void)startBroadcasting
{
    if (self.debugLogging) {
        NSLog(@"Starting to broadcast.");
    }
    NSAssert(!self.inUse, @"RCWKGConnection objects can only be used once to establish streams.");
    self.inUse = YES;
    self.isBroadcasting = YES;

    self.broadcastingService = [[NSNetService alloc] initWithDomain:@"local."
                                                               type:@"_rcwkeyg._tcp."
                                                               name:@""];
    self.broadcastingService.delegate = self;
#if TARGET_OS_IPHONE
    self.broadcastingService.includesPeerToPeer = YES;
#endif
    NSData *txtRecord = [NSNetService dataFromTXTRecordDictionary:@{@"name": self.identifier}];
    [self.broadcastingService setTXTRecordData:txtRecord];
    [self.broadcastingService publishWithOptions:NSNetServiceListenForConnections];
}

- (void)startListening
{
    if (self.debugLogging) {
        NSLog(@"Starting to listen.");
    }
    NSAssert(!self.inUse, @"RCWKGConnection objects can only be used once to establish streams.");
    self.isBroadcasting = NO;

    self.listeningService = [[NSNetServiceBrowser alloc] init];
#if TARGET_OS_IPHONE
    self.listeningService.includesPeerToPeer = YES;
#endif
    self.listeningService.delegate = self;
    [self.listeningService searchForServicesOfType:@"_rcwkeyg._tcp." inDomain:@"local."];
}

- (void)stop
{
    if (self.debugLogging) {
        NSLog(@"Stopping finder.");
    }
    self.listeningService.delegate = nil;
    [self.listeningService stop];
    self.listeningService = nil;

    self.broadcastingService.delegate = nil;
    [self.broadcastingService stop];
    [self.broadcastingService stopMonitoring];

    self.broadcastingService = nil;

    [self.peerServices removeAllObjects];

    self.isBroadcasting = NO;
    self.inUse = NO;
}


#pragma mark - Publishing

- (void)netServiceDidPublish:(NSNetService *)ns
{
    if (self.debugLogging) {
        NSLog(@"Bonjour Service Published: domain(%@) type(%@) name(%@) port(%i)", [ns domain], [ns type], [ns name], (int)[ns port]);
    }
}

- (void)netService:(NSNetService *)sender didAcceptConnectionWithInputStream:(NSInputStream *)input outputStream:(NSOutputStream *)output
{
    if (self.debugLogging) {
        NSLog(@"Published service did accept connection with streams.");
    }
    [sender stop];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate finder:self connectedWithInput:input output:output];
    });
}

- (void)netService:(NSNetService *)ns didNotPublish:(NSDictionary *)errorDict
{
    if (self.debugLogging) {
        NSLog(@"Netservice did not publish: %@", errorDict);
    }
    [self stop];
    NSString *msg = [NSString stringWithFormat:@"Failed to Publish Service: domain(%@) type(%@) name(%@) - %@", [ns domain], [ns type], [ns name], errorDict];
    NSError *error = [NSError errorWithDomain:errorDict[NSNetServicesErrorDomain] code:[errorDict[NSNetServicesErrorCode] intValue] userInfo:@{NSLocalizedDescriptionKey: msg}];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate finder:self didError:error];
    });
}

#pragma mark - Listening

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser
{
    if (self.debugLogging) {
        NSLog(@"WillSearch");
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)sender didNotSearch:(NSDictionary *)errorInfo
{
    if (self.debugLogging) {
        NSLog(@"DidNotSearch: %@", errorInfo);
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)sender
           didFindService:(NSNetService *)netService
               moreComing:(BOOL)moreServicesComing
{
    if (self.debugLogging) {
        NSLog(@"netService didFindService: %@", [netService name]);
    }

    //we must retain netService or it doesn't resolve
    [self.peerServices addObject:netService];

    //must resolve since TXTRecordData isn't available til we resolve
    netService.delegate = self;
    [netService resolveWithTimeout:9];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)sender
         didRemoveService:(NSNetService *)netService
               moreComing:(BOOL)moreServicesComing
{
    if (self.debugLogging) {
        NSLog(@"DidRemoveService: %@", [netService name]);
    }

    netService.delegate = nil;
    [netService stopMonitoring];

    [self.peerServices removeObject:netService];
}

- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data
{
    if (self.debugLogging) {
        NSDictionary *d = [NSNetService dictionaryFromTXTRecordData:[sender TXTRecordData]];
        NSLog(@"didUpdateTXTRecordData: %@", d);
    }
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)sender
{
    if (self.debugLogging) {
        NSLog(@"DidStopSearch");
    }
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict
{
    sender.delegate = nil;
    [self.peerServices removeObject:sender];
    if (self.debugLogging) {
        NSLog(@"DidNotResolve: %@", errorDict);
    }
}

- (void)netServiceWillResolve:(NSNetService *)sender
{
    if (self.debugLogging) {
        NSLog(@"willresolve");
    }
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender
{
    if (self.debugLogging) {
        NSDictionary *d = [NSNetService dictionaryFromTXTRecordData:[sender TXTRecordData]];
        NSLog(@"DidResolve: %@", d);
    }
    if (!self.isBroadcasting) {
        [self checkIfListenedToValidService:sender];
    }
}

- (void)checkIfListenedToValidService:(NSNetService *)service
{
    NSDictionary *dict = [NSNetService dictionaryFromTXTRecordData:service.TXTRecordData];
    NSData *nameData = dict[@"name"];
    NSString *name = [[NSString alloc] initWithData:nameData encoding:NSUTF8StringEncoding];
    if ([self.identifier isEqualToString:name]) {
        NSInputStream *input;
        NSOutputStream *output;
        if ([service getInputStream:&input outputStream:&output]) {
            [self stop];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate finder:self connectedWithInput:input output:output];
            });
        } else {
            [self stop];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error = [NSError errorWithDomain:RCWBonjourConnectionFinderErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"Could not create streams from net service."}];
                [self.delegate finder:self didError:error];
            });
        }
    }
}

- (void)emptyPeerServicesList
{
    for (NSNetService *service in self.peerServices) {
        service.delegate = nil;
    }
    [self.peerServices removeAllObjects];
}

@end
