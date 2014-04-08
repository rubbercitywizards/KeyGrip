//
//  RCWSocketServerConnection.m
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

#import "RCWSocketServerConnection.h"
#import "RCWDataStreamCollector.h"
#import "RCWDataStreamEmitter.h"
#include <sys/socket.h>
#include <netinet/in.h>

@interface RCWSocketServerConnection ()
@property (nonatomic, strong) RCWDataStreamEmitter *emitter;
@property (nonatomic, strong) RCWDataStreamCollector *collector;

@property (atomic, readwrite, strong) NSString *host;
@property (atomic, readwrite, assign) NSUInteger port;
@property (atomic, readwrite, assign) BOOL isConnected;
@property (atomic, readwrite, assign) BOOL isListening;

@property (assign) int server_socket;
@property (assign) int server_connection;

@property (atomic) dispatch_queue_t socketQueue;

@end

@implementation RCWSocketServerConnection
@synthesize delegate=_delegate;
@synthesize port=_port;

- (id)init
{
    if (self = [super init]) {
        _emitter = [[RCWDataStreamEmitter alloc] init];
        _collector = [[RCWDataStreamCollector alloc] init];

        __weak typeof(self) weakSelf = self;
        _collector.callback = ^(NSData *data) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [weakSelf.delegate connection:weakSelf didReceiveData:data];
            });
        };

        self.socketQueue = dispatch_queue_create("com.rubbercitywizards.keygrip.server.socket", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc
{
    [self stop];
}

- (void)bindToPort:(RCWKGSocketServerPort)port
{
    [self stop];
    _port = port;

    self.server_socket = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    struct sockaddr_in sin;
    memset(&sin, 0, sizeof(sin));
    sin.sin_len = sizeof(sin);
    sin.sin_family = AF_INET;
    sin.sin_port = htons(self.port);
    sin.sin_addr.s_addr= INADDR_ANY;

    int set = 1;
    setsockopt(self.server_socket, SOL_SOCKET, SO_NOSIGPIPE, (void *)&set, sizeof(int));

    int res = bind(self.server_socket, (struct sockaddr *)&sin, sizeof(sin));
    assert(res == 0);

    socklen_t len = sizeof(sin);
    // We do this just to get the port
    getsockname(self.server_socket, (struct sockaddr *)&sin, &len);

    listen(self.server_socket, 5);
    self.port = ntohs(sin.sin_port);
}

// http://www.minek.com/files/unix_examples/poll.html
- (void)startListening
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        struct sockaddr sock_conn;
        socklen_t c;
        self.isListening = YES;
        self.server_connection = accept(self.server_socket, &sock_conn, &c);

        self.isConnected = YES;
        self.isListening = NO;

        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.delegate connectionDidConnect:self];
        });

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            UInt8 buffer[2048];

            [self writePendingBytes];
            while (self.isConnected) {
                /* Set up polling using select. */
                struct timeval timeOut;
                timeOut.tv_sec = 1;
                fd_set fileDescriptorsToPoll;
                int maxfd = self.server_connection+1;
                FD_ZERO(&fileDescriptorsToPoll);
                FD_SET(self.server_connection,&fileDescriptorsToPoll);
                
                /* Wait for some input. */
                select(maxfd, &fileDescriptorsToPoll, (fd_set *) 0, (fd_set *) 0, &timeOut);

                if( FD_ISSET(self.server_connection, &fileDescriptorsToPoll))
                {
                    memset(buffer, 0, sizeof(buffer));
                    ssize_t bytesRead = recv(self.server_connection, buffer, sizeof(buffer), 0);
                    /* If error or eof, terminate. */
                    if (bytesRead < 0) {
                        [self stop];
                        NSError *error = [NSError errorWithDomain:@"RCWSocketServer" code:0 userInfo:@{NSLocalizedDescriptionKey: @"Socket connection failed."}];
                        dispatch_sync(dispatch_get_main_queue(), ^{
                            [self.delegate connection:self failedWith:error];
                        });
                    } else if (bytesRead > 0) {
                        NSError *error = nil;
                        if ([self.collector write:buffer length:bytesRead error:&error] == -1) {
                            [self stop];
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                [self.delegate connection:self failedWith:error];
                            });
                        }
                    }
                }
            }
            [self closeUnixBits];
        });
    });
}

- (void)closeUnixBits
{
    if (self.server_connection > 0) {
        close(self.server_connection);
        close(self.server_socket);
        self.server_connection = 0;
        self.server_socket = 0;
    }
}

- (void)stop
{
    [self closeUnixBits];

    self.isListening = NO;
    self.isConnected = NO;

    [self.emitter reset];
    [self.collector reset];
}

- (void)sendData:(NSData *)data
{
    [self.emitter emitData:data];
    [self writePendingBytes];
}

- (void)writePendingBytes
{
    dispatch_async(self.socketQueue, ^{
        size_t const bufferSize = 4096;
        uint8_t buffer[bufferSize];
        
        while (self.isConnected && self.emitter.hasData) {
            memset(buffer, 0, sizeof(uint8_t) * bufferSize);

            NSUInteger count = [self.emitter attemptToRead:buffer maxLength:bufferSize];
            ssize_t bytesWritten = send(self.server_connection, buffer, count, 0);
            [self.emitter markActualByteCountRead:bytesWritten];
        }
    });
}

@end

