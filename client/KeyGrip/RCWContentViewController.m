//
//  RCWContentViewController.m
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

#import <CoreData/CoreData.h>
#import "RCWContentViewController.h"
#import "RCWKGClientAPI.h"
#import "RCWHealthMeter.h"
#import "RCWGentleErrorNotificationView.h"
#import "RCWBonjourConnection.h"
#import "RCWSocketClientConnection.h"
#import "RCWWebView.h"

@interface RCWContentViewController ()
<RCWKGClientAPIDelegate, RCWWebViewJavascriptDelegate>

@property (nonatomic, strong) IBOutlet RCWWebView *webView;
@property (nonatomic, strong) RCWKGClientAPI *client;
@property (nonatomic, strong) RCWHealthMeter *meter;
@property (nonatomic, weak) RCWGentleErrorNotificationView *errorView;

@end

@implementation RCWContentViewController

#pragma mark - View Controller Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setUpHealthMeter];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self establishConnection];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.client stop];
}


#pragma - RCWKGClientAPIDelegate methods

- (void)clientDidConnect:(RCWKGClientAPI *)client
{
    [self.meter setHealthy:YES];
    [self refresh:nil];
}

- (void)clientReceivedServerPing:(RCWKGClientAPI *)client
{
    [self.meter pulseAnimation];
}

- (void)client:(RCWKGClientAPI *)client failedWithError:(NSError *)error
{
    [self.meter setHealthy:NO];
    [self displayError:error];
    [self establishConnection];
}

- (void)client:(RCWKGClientAPI *)client notifiedOfServerError:(NSError *)error
{
    [self displayError:error];
}

- (void)client:(RCWKGClientAPI *)client receivedScript:(NSString *)html named:(NSString *)filename
{
    [self setTitleBarText:filename];
    [self.webView useHTMLScript:html];
}

- (void)client:(RCWKGClientAPI *)client notifiedOfPastedTextID:(NSString *)textID
{
    [self.webView pastedCodeWithTextID:textID];
}


#pragma mark - RCWWebViewDelegate

- (void)webView:(RCWWebView *)webView didSelectTextWithID:(NSString *)textID
{
    [self.client pasteTextWithID:textID];
}


#pragma mark - Helper Methods

- (void)setUpHealthMeter
{
    self.meter = [[RCWHealthMeter alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
    [self.meter setHealthy:NO];
    UIBarButtonItem *meterItem = [[UIBarButtonItem alloc] initWithCustomView:self.meter];

    self.navigationItem.leftBarButtonItems = @[self.navigationItem.leftBarButtonItem, meterItem];
}

- (void)establishConnection
{
    [self.meter setHealthy:NO];
    [self showTitleBarSpinner];

    [self.client stop];

    NSString *identifier = [[NSUserDefaults standardUserDefaults] stringForKey:@"bonjourIdentifier"];
    RCWBonjourConnection *connection = [[RCWBonjourConnection alloc] initWithIdentifier:identifier];
    self.client = [[RCWKGClientAPI alloc] initWithConnection:connection];
    self.client.delegate = self;

    [connection shareConnection];
}

- (void)showTitleBarSpinner
{
    UIActivityIndicatorView *activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [activity startAnimating];
    self.navigationItem.titleView = activity;
}

- (void)setTitleBarText:(NSString *)text
{
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.minimumScaleFactor = 0.5;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.text = [text lastPathComponent];
    [titleLabel sizeToFit];
    self.navigationItem.titleView = titleLabel;
}

- (void)displayError:(NSError *)error
{
    [self clearExistingError];

    self.errorView = [RCWGentleErrorNotificationView viewFromNib];
    [self.view addSubview:self.errorView];
    [self.errorView displayError:error];
}

- (void)clearExistingError
{
    [self.errorView animateAndRemove];
}


#pragma mark - IBActions

- (IBAction)refresh:(id)sender
{
    [self showTitleBarSpinner];
    [self.client askServerForScript];
}

- (IBAction)openSettings:(id)sender
{
    UINavigationController *settingsNav = [self.storyboard instantiateViewControllerWithIdentifier:@"settingsNavigationController"];
    [self presentViewController:settingsNav animated:YES completion:nil];
}



@end
