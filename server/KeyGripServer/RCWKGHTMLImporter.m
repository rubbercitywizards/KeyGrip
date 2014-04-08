//
//  RCWKGHTMLImporter.m
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

#import <WebKit/WebKit.h>
#import "RCWKGHTMLImporter.h"

@interface RCWKGHTMLImporter ()
<NSFilePresenter>
@property (strong) NSURL *conversionToolURL;
@property (strong) NSURL *fileURL;
@property (strong) NSDate *fileLastModifiedDate;
@property (strong, readwrite) NSString *htmlOutput;
@property (strong) WebView *webView;
@end

@implementation RCWKGHTMLImporter

- (instancetype)init
{
    if (self = [super init]) {
        // Here's where we could experiment with different parsing scripts
        _conversionToolURL = [[NSBundle mainBundle] URLForResource:@"markdown" withExtension:@"pl"];
        _webView = [[WebView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    }
    return self;
}

- (void)dealloc
{
    [NSFileCoordinator removeFilePresenter:self];
}

- (NSURL *)presentedItemURL
{
    return self.fileURL;
}

- (NSOperationQueue *)presentedItemOperationQueue
{
    return [NSOperationQueue mainQueue];
}

- (void)presentedItemDidChange
{
    NSError *error = nil;
    NSDate *newDate = [self getFileURLLastModified:self.fileURL error:&error];

    if (!newDate) {
        [self.delegate importer:self didFailToLoadFile:self.fileURL error:error];
    } else {
        if ([newDate timeIntervalSinceReferenceDate] > [self.fileLastModifiedDate timeIntervalSinceReferenceDate]) {
            self.fileLastModifiedDate = newDate;
            if (![self importFile:self.fileURL error:&error]) {
                [self.delegate importer:self didFailToLoadFile:self.fileURL error:error];
            } else {
                [self.delegate importer:self didReloadFile:self.fileURL];
            }
        }
    }
}

- (void)presentedItemDidMoveToURL:(NSURL *)newURL
{
    self.fileLastModifiedDate = nil;
    self.fileURL = newURL;
    [self presentedItemDidChange];
}

- (BOOL)importFile:(NSURL *)fileURL error:(NSError *__autoreleasing *)error
{
    [NSFileCoordinator removeFilePresenter:self];

    if (fileURL == nil) {
        if (error) {
            *error = [NSError errorWithDomain:@"RCWKGHTMLImporter" code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"No file given"}];
        }
        return NO;
    }

    self.fileLastModifiedDate = [self getFileURLLastModified:fileURL error:error];
    if (!self.fileLastModifiedDate) { return NO; }

    self.fileURL = fileURL;

    NSTask *conversionTask = [[NSTask alloc] init];
    [conversionTask setLaunchPath:self.conversionToolURL.path];

    NSPipe *inPipe = [NSPipe pipe];
    NSPipe *outPipe = [NSPipe pipe];

    [conversionTask setStandardInput:inPipe];
    [conversionTask setStandardOutput:outPipe];

    [conversionTask launch];

    [fileURL startAccessingSecurityScopedResource];
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL options:NSDataReadingUncached error:error];
    [fileURL stopAccessingSecurityScopedResource];
    if (!fileData) {
        return NO;
    }
    [[inPipe fileHandleForWriting] writeData:fileData];
    [[inPipe fileHandleForWriting] closeFile];

    [conversionTask waitUntilExit];
    NSData *outputData = [[outPipe fileHandleForReading] readDataToEndOfFile];

    NSString *javascript = [NSString stringWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"selections" withExtension:@"js"] encoding:NSUTF8StringEncoding error:error];
    if (!javascript) { return NO; }
    NSString *zepto = [NSString stringWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"zepto" withExtension:@"js"] encoding:NSUTF8StringEncoding error:error];
    if (!zepto) { return NO; }
    NSString *css = [NSString stringWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"display" withExtension:@"css"] encoding:NSUTF8StringEncoding error:error];
    if (!css) { return NO; }
    NSString *html = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];

    self.htmlOutput = [NSString stringWithFormat:@"<html><head><meta name='viewport' content='width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no' /></head><body>%@\n<script>\n%@\n%@\n</script>\n<style>\n%@\n</style></body></html>",
                       html,
                       zepto,
                       javascript,
                       css];

    [self.webView.mainFrame loadHTMLString:self.htmlOutput baseURL:[[NSBundle mainBundle] resourceURL]];

    [NSFileCoordinator addFilePresenter:self];

    return YES;
}

- (NSString *)textBlockWithID:(NSString *)itemId
{
    NSString *script = [NSString stringWithFormat:@"contentForCodeWithID(\"%@\")", itemId];
    NSString *result = [[self.webView windowScriptObject] evaluateWebScript:script];
    return result;
}

- (NSDate *)getFileURLLastModified:(NSURL *)url error:(NSError *__autoreleasing *)error
{
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:self];

    __block NSDate *date = nil;

    [url startAccessingSecurityScopedResource];
    [coordinator coordinateReadingItemAtURL:url options:0 error:error byAccessor:^(NSURL *newURL) {
        [newURL getResourceValue:&date forKey:NSURLContentModificationDateKey error:error];
    }];
    [url stopAccessingSecurityScopedResource];

    if (error && *error) { return nil; }
    else { return date; }
}

@end
