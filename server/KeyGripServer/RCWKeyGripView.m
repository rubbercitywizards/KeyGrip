//
//  RCWKeyGripView.m
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

#import "RCWKeyGripView.h"
#import "RCWAppDelegate.h"

@interface RCWKeyGripView ()
@property BOOL highlight;
@end

@implementation RCWKeyGripView

- (NSSet *)extensions
{
    return [NSSet setWithArray:@[@"txt", @"md", @"markdown"]];
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self registerForDraggedTypes:@[NSURLPboardType]];
    }
    return self;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    self.highlight = YES;
    [self setNeedsDisplay: YES];

    NSPasteboard *pboard = [sender draggingPasteboard];
    if ([[pboard types] containsObject:NSURLPboardType]) {
        NSURL *draggedFile = [NSURL URLFromPasteboard:pboard];
        if ([self.extensions containsObject:[draggedFile.pathExtension lowercaseString]]) {
            return NSDragOperationGeneric;
        } else {
            return NSDragOperationNone;
        }
    } else {
        return NSDragOperationNone;
    }
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    self.highlight = NO;
    [self setNeedsDisplay: YES];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    self.highlight = NO;
    [self setNeedsDisplay: YES];
    return YES;
}

- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ([[pboard types] containsObject:NSURLPboardType]) {
        NSURL *draggedFile = [NSURL URLFromPasteboard:pboard];
        if ([self.extensions containsObject:[draggedFile.pathExtension lowercaseString]]) {
            return YES;
        } else {
            return NO;
        }
    } else {
        return NO;
    }
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ([[pboard types] containsObject:NSURLPboardType]) {
        NSURL *draggedFile = [NSURL URLFromPasteboard:pboard].filePathURL;
        if ([self.extensions containsObject:[draggedFile.pathExtension lowercaseString]]) {
            RCWAppDelegate *delegate = (RCWAppDelegate *)[NSApplication sharedApplication].delegate;
            [delegate handleDroppedFile:draggedFile];
        }
    }
}

- (void)drawRect:(NSRect)rect
{
    [super drawRect:rect];
    if (self.highlight) {
        [[NSColor grayColor] set];
        [NSBezierPath setDefaultLineWidth:5];
        [NSBezierPath strokeRect:[self bounds]];
    }
}

@end
