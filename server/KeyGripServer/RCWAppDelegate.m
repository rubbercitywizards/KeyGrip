//
//  RCWAppDelegate.m
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

#import "RCWAppDelegate.h"
#import "RCWKGHTMLImporter.h"
#import "RCWKGHTMLImporter.h"
#import "RCWKGServerAPI.h"
#import "RCWBonjourConnection.h"

@interface RCWAppDelegate ()
<NSTextFieldDelegate, RCWKGServerAPIDelegate, RCWKGHTMLImporterDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (unsafe_unretained) IBOutlet NSTextView *lastPasteTextView;

@property (strong) NSURL *fileURL;
@property (strong) NSDate *lastPastedDate;
@property (strong) NSString *lastPastedText;

@property (strong) RCWKGServerAPI *serverAPI;
@property (strong) RCWKGHTMLImporter *importer;

@property (readonly) NSString *appVersionString;

@end

@implementation RCWAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // In honor of Minecraft's default user name
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"bonjourIdentifier": @"Steve"}];

    self.fileURL = [self getFileFromSavedBookmark];
    if (self.fileURL) {
        [self attemptToEstablishConnection];
        [self loadAndSendFileContentsToClient];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    [self application:sender openFile:[filenames firstObject]];
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    self.fileURL = [self saveURLAsBookmark:[NSURL fileURLWithPath:filename]];
    [self loadAndSendFileContentsToClient];
    return YES;
}

- (IBAction)openDocument:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    if ([panel runModal] == NSOKButton) {
        self.fileURL = [self saveURLAsBookmark:[panel URL]];
        [self loadAndSendFileContentsToClient];
    }
}

- (IBAction)resetServer:(NSButton *)sender
{
    [self attemptToEstablishConnection];
}

- (void)handleDroppedFile:(NSURL *)file
{
    self.fileURL = [self saveURLAsBookmark:file];
    [self loadAndSendFileContentsToClient];
}

- (NSString *)appVersionString
{
    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString* version = [infoDict objectForKey:@"CFBundleVersion"];
    return [NSString stringWithFormat:@"KeyGrip v%@", version];
}


#pragma mark - Connection Helpers

- (void)attemptToEstablishConnection
{
    [self.serverAPI stop];

    NSString *identifier = [[NSUserDefaults standardUserDefaults] stringForKey:@"bonjourIdentifier"];
    RCWBonjourConnection *connection = [[RCWBonjourConnection alloc] initWithIdentifier:identifier];
    self.serverAPI = [[RCWKGServerAPI alloc] initWithConnection:connection];
    self.serverAPI.delegate = self;
    [connection findConnection];
}

- (void)loadAndSendFileContentsToClient
{
    NSError *error = nil;

    self.importer = [[RCWKGHTMLImporter alloc] init];
    self.importer.delegate = self;
    if ([self.importer importFile:self.fileURL error:&error]) {
        if (self.serverAPI.isConnected) {
            [self.serverAPI sendScriptHTML:self.importer.htmlOutput named:self.fileURL.path];
        }
    } else {
        if (self.serverAPI.isConnected) {
            [self.serverAPI notifyClientOfErrorMessage:error.localizedDescription];
        } else {
            NSLog(@"Unable to load file: %@", error);
        }
        self.fileURL = nil;
    }
}


#pragma mark - Security Scoped Bookmark Stuff

- (NSURL *)saveURLAsBookmark:(NSURL *)url
{
    if (url == nil) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"lastFileBookmark"];
        return nil;
    }

    NSError *error = nil;
    [url startAccessingSecurityScopedResource];
    NSData *bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope | NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess
                     includingResourceValuesForKeys:@[NSURLPathKey]
                                      relativeToURL:nil
                                              error:&error];
    [url stopAccessingSecurityScopedResource];

    if (!bookmark) {
        NSLog(@"unable to create security scoped bookmark, %@", error);
        return nil;
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:bookmark forKey:@"lastFileBookmark"];
        return [self getFileFromSavedBookmark];
    }
}

- (NSURL *)getFileFromSavedBookmark
{
    BOOL isStale = NO;
    NSError *error = nil;
    NSData *bookmark = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastFileBookmark"];
    NSURL *url = [NSURL URLByResolvingBookmarkData:bookmark options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:&isStale error:&error];

    if (!url) {
        NSLog(@"Unable to retrieve url from security scoped bookmark, %@", error);
        return nil;
    } else {
        if (isStale) {
            return [self saveURLAsBookmark:url];
        } else {
            return url;
        }
    }
}


#pragma mark - Text Editing

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    [[NSUserDefaults standardUserDefaults] setObject:control.stringValue forKey:@"bonjourIdentifier"];
    [self attemptToEstablishConnection];
    return YES;
}


#pragma mark - RCWKGServerAPI Delegate

- (void)serverDidConnect:(RCWKGServerAPI *)server
{
    NSLog(@"Connection established!");
}

- (void)serverReceivedClientPing:(RCWKGServerAPI *)server
{
    // Noop for now
}

- (void)server:(RCWKGServerAPI *)server failedWithError:(NSError *)error
{
    NSLog(@"Server restarting because of error: %@", error);
    [self attemptToEstablishConnection];
}

- (void)server:(RCWKGServerAPI *)client notifiedOfClientError:(NSError *)error
{
    NSLog(@"Client saw error: %@", error);
}

- (void)serverAskedForScript:(RCWKGServerAPI *)server
{
    [self loadAndSendFileContentsToClient];
}

- (void)server:(RCWKGServerAPI *)server askedToPasteTextWithId:(NSString *)textID
{
    self.lastPastedText = [self.importer textBlockWithID:textID];
    self.lastPastedDate = [NSDate date];

    [[self.lastPasteTextView textStorage] setFont:[NSFont fontWithName:@"Monaco" size:12]];

    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] writeObjects:@[self.lastPastedText] ];
    [self.serverAPI pastedTextWithID:textID];
}


#pragma mark - RCWKGHTMLImporterDelegate

- (void)importer:(RCWKGHTMLImporter *)importer didReloadFile:(NSURL *)file
{
    self.fileURL = [self saveURLAsBookmark:file];
    [self.serverAPI sendScriptHTML:self.importer.htmlOutput named:self.fileURL.lastPathComponent];
}

- (void)importer:(RCWKGHTMLImporter *)importer didFailToLoadFile:(NSURL *)file error:(NSError *)error
{
    self.fileURL = nil;
    [self saveURLAsBookmark:nil];
    [self.serverAPI notifyClientOfErrorMessage:error.localizedDescription];
}


@end
