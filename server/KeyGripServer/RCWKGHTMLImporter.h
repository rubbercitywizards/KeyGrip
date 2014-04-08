//
//  RCWKGHTMLImporter.h
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

@class RCWKGHTMLImporter;

@protocol RCWKGHTMLImporterDelegate <NSObject>
- (void)importer:(RCWKGHTMLImporter *)importer didReloadFile:(NSURL *)file;
- (void)importer:(RCWKGHTMLImporter *)importer didFailToLoadFile:(NSURL *)file error:(NSError *)error;
@end

@interface RCWKGHTMLImporter : NSObject

/**
 Reads in the file and converts it to html. Currently, it uses the embedded `markdown` perl script to do the translation using NSTask. Someday this can be made to swap out other processor scrips. As long as the script reads from stdin and prints to stdout, it will work with this class.

 \param fileURL The file url to read in.
*/
- (BOOL)importFile:(NSURL *)fileURL error:(NSError **)error;

- (NSString *)textBlockWithID:(NSString *)itemId;

@property (readonly) NSString *htmlOutput;

@property (weak) id<RCWKGHTMLImporterDelegate> delegate;

@end
