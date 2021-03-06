//
//  RCWWebView.h
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

#import <UIKit/UIKit.h>

@class RCWWebView;

@protocol RCWWebViewJavascriptDelegate <NSObject>
- (void)webView:(RCWWebView *)webView didSelectTextWithID:(NSString *)textID;
@end

@interface RCWWebView : UIWebView
@property (nonatomic, weak) IBOutlet id<RCWWebViewJavascriptDelegate> javascriptDelegate;
- (void)pastedCodeWithTextID:(NSString *)textID;
- (void)useHTMLScript:(NSString *)html;
@end
