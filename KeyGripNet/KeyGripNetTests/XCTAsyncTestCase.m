//
//  XCTAsyncTestCase.m
//  Modified by Sveinung Kval Bakken on 16/10/13
//  to serve as a drop-in replacement for GHAsyncTestCase using XCTest
//  Original copyright notice below:
//
//  GHAsyncTestCase.m
//  GHUnit
//
//  Created by Gabriel Handford on 4/8/09.
//  Copyright 2009. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

#import "XCTAsyncTestCase.h"
#import <objc/runtime.h>

typedef enum {
    kXCTUnitAsyncErrorNone,
    kXCTUnitAsyncErrorUnprepared,
    kXCTUnitAsyncErrorTimedOut,
    kXCTUnitAsyncErrorInvalidStatus
} XCTUnitAsyncError;

@implementation XCTAsyncTestCase

@synthesize runLoopModes=_runLoopModes;


// Internal GHUnit setUp
- (void)setUp {
    [super setUp];
    lock_ = [[NSRecursiveLock alloc] init];
    prepared_ = NO;
    notifiedStatus_ = kXCTUnitWaitStatusUnknown;
}

// Internal GHUnit tear down
- (void)tearDown {
    [super tearDown];
    waitSelector_ = NULL;
    if (prepared_) [lock_ unlock]; // If we prepared but never waited we need to unlock
    lock_ = nil;
}

- (void)prepare {
    [self prepare:self.selector];
}

- (void)prepare:(SEL)selector {
    [lock_ lock];
    prepared_ = YES;
    waitSelector_ = selector;
    notifiedStatus_ = kXCTUnitWaitStatusUnknown;
}

- (XCTUnitAsyncError)_waitFor:(NSInteger)status timeout:(NSTimeInterval)timeout {
    if (!prepared_) {
        return kXCTUnitAsyncErrorUnprepared;
    }
    prepared_ = NO;
    
    waitForStatus_ = status;
    
    if (!_runLoopModes)
        _runLoopModes = [NSArray arrayWithObjects:NSDefaultRunLoopMode, NSRunLoopCommonModes, nil];
    
    NSTimeInterval checkEveryInterval = 0.05;
    NSDate *runUntilDate = [NSDate dateWithTimeIntervalSinceNow:timeout];
    BOOL timedOut = NO;
    NSUInteger runIndex = 0;
    while(notifiedStatus_ == kXCTUnitWaitStatusUnknown) {
        NSString *mode = [_runLoopModes objectAtIndex:(runIndex++ % [_runLoopModes count])];
        
        [lock_ unlock];
        @autoreleasepool {
            if (!mode || ![[NSRunLoop currentRunLoop] runMode:mode beforeDate:[NSDate dateWithTimeIntervalSinceNow:checkEveryInterval]])
                // If there were no run loop sources or timers then we should sleep for the interval
                [NSThread sleepForTimeInterval:checkEveryInterval];
        }
        [lock_ lock];
        
        // If current date is after the run until date
        if ([runUntilDate compare:[NSDate date]] == NSOrderedAscending) {
            timedOut = YES;
            break;
        }
    }
    [lock_ unlock];
    
    if (timedOut) {
        return kXCTUnitAsyncErrorTimedOut;
    } else if (waitForStatus_ != notifiedStatus_) {
        return kXCTUnitAsyncErrorInvalidStatus;
    }
    
    return kXCTUnitAsyncErrorNone;
}

- (void)waitFor:(NSInteger)status timeout:(NSTimeInterval)timeout {
    [NSException raise:NSDestinationInvalidException format:@"Deprecated; Use waitForStatus:timeout:"];
}

- (void)waitForStatus:(NSInteger)status timeout:(NSTimeInterval)timeout {
    XCTUnitAsyncError error = [self _waitFor:status timeout:timeout];
    if (error == kXCTUnitAsyncErrorTimedOut) {
        XCTFail(@"Request timed out");
    } else if (error == kXCTUnitAsyncErrorInvalidStatus) {
        XCTFail(@"Request finished with the wrong status: %ld != %ld", status, notifiedStatus_);
    } else if (error == kXCTUnitAsyncErrorUnprepared) {
        XCTFail(@"Call prepare before calling asynchronous method and waitForStatus:timeout:");
    }
}

- (void)waitForTimeout:(NSTimeInterval)timeout {
    XCTUnitAsyncError error = [self _waitFor:-1 timeout:timeout];
    if (error != kXCTUnitAsyncErrorTimedOut) {
        XCTFail(@"Request should have timed out");
    }
}

// Similar to _waitFor:timeout: but just runs the loops
// From Robert Palmer, pauseForTimeout
- (void)runForInterval:(NSTimeInterval)interval {
	NSTimeInterval checkEveryInterval = 0.05;
	NSDate *runUntilDate = [NSDate dateWithTimeIntervalSinceNow:interval];
    
	if (!_runLoopModes)
		_runLoopModes = [NSArray arrayWithObjects:NSDefaultRunLoopMode, NSRunLoopCommonModes, nil];
    
	NSUInteger runIndex = 0;
    
	while ([runUntilDate compare:[NSDate dateWithTimeIntervalSinceNow:0]] == NSOrderedDescending) {
		NSString *mode = [_runLoopModes objectAtIndex:(runIndex++ % [_runLoopModes count])];
        
		[lock_ unlock];
		@autoreleasepool {
			if (!mode || ![[NSRunLoop currentRunLoop] runMode:mode beforeDate:[NSDate dateWithTimeIntervalSinceNow:checkEveryInterval]])
				// If there were no run loop sources or timers then we should sleep for the interval
				[NSThread sleepForTimeInterval:checkEveryInterval];
		}
		[lock_ lock];
	}
}

- (void)notify:(NSInteger)status {
    [self notify:status forSelector:NULL];
}

- (void)notify:(NSInteger)status forSelector:(SEL)selector {
    // Note: If this is called from a stray thread or delayed call, we may not be in an autorelease pool
    @autoreleasepool {
        
        // Make sure the notify is for the currently waiting test
        if (selector != NULL && !sel_isEqual(waitSelector_, selector)) {
            NSLog(@"Warning: Notified from %@ but we were waiting for %@", NSStringFromSelector(selector), NSStringFromSelector(waitSelector_));
        }  else {
            [lock_ lock];
            notifiedStatus_ = status;
            [lock_ unlock];
        }
        
    }
}

@end
