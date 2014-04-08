//
//  RCWWebView.m
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

#import "RCWWebView.h"

@interface RCWWebView() <UIWebViewDelegate>
@property (nonatomic) CGFloat lastYPosition;
@end

@implementation RCWWebView

- (void)awakeFromNib
{
    self.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    self.delegate = self;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSArray *pathComponents = request.URL.pathComponents;
    if ([pathComponents[1] isEqualToString:@"paste"]) {
        [self.javascriptDelegate webView:self didSelectTextWithID:pathComponents[2]];
        return NO;
    } else {
        return YES;
    }
}

- (void)pastedCodeWithTextID:(NSString *)textID
{
    NSString *javascript = [NSString stringWithFormat:@"pastedCodeWithID(\"%@\")", textID];
    [self stringByEvaluatingJavaScriptFromString:javascript];
}

- (void)useHTMLScript:(NSString *)html
{
    self.lastYPosition = [[self stringByEvaluatingJavaScriptFromString:@"document.body.scrollTop"] integerValue];

    // Fade out and back in when done because otherwise it flickers while returning to scroll position
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        if (finished) {
            [self loadHTMLString:html baseURL:nil];
        }
    }];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    NSString *command = [NSString stringWithFormat:@"document.body.scrollTop = %0.0f;", self.lastYPosition];
    [self stringByEvaluatingJavaScriptFromString:command];
    [UIView animateWithDuration:0.2 delay:0.1 options:0 animations:^{
        self.alpha = 1;
    } completion:nil];
}

@end
