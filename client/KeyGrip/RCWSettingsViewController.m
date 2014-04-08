//
//  RCWSettingsViewController.m
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

#import "RCWSettingsViewController.h"
#import "RCWTextFieldCell.h"
#import "RCWLabelCell.h"

@interface RCWSettingsViewController ()
<UITextFieldDelegate>

// Table cells

@property (nonatomic, strong) RCWLabelCell *appVersionCell;
@property (nonatomic, strong) RCWTextFieldCell *bonjourIdentifierCell;
@end

@implementation RCWSettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setUpCellProperties];
}

- (IBAction)donePressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 1) {
        return @"Give the server the same identifier so they can find each other on the network.";
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return 1;
        case 1:
            return 1;
        default:
            NSAssert(false, @"Unknown section number: %ld", (long)section);
            break;
    }
    return -1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:
            switch (indexPath.row) {
                case 0:
                    return self.appVersionCell;
                default:
                    NSAssert(false, @"Unknown row in server section: %@", indexPath);
                    break;
            }
        case 1:
            switch (indexPath.row) {
                case 0:
                    return self.bonjourIdentifierCell;
                default:
                    NSAssert(false, @"Unknown row in server section: %@", indexPath);
                    break;
            }
        default:
            NSAssert(false, @"Unknown section number: %ld", (long)indexPath.section);
            break;
    }
    return nil;
}

- (void)setUpCellProperties
{
    self.appVersionCell = [self.tableView dequeueReusableCellWithIdentifier:@"LabelCell"];
    NSAssert(self.appVersionCell, @"Could not load label cell");
    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString* version = [infoDict objectForKey:@"CFBundleVersion"];
    self.appVersionCell.leftLabel.text = @"App Version";
    self.appVersionCell.rightLabel.text = version;

    self.bonjourIdentifierCell = [self.tableView dequeueReusableCellWithIdentifier:@"TextFieldCell"];
    NSAssert(self.bonjourIdentifierCell, @"Could not load text field cell for server section");
    self.bonjourIdentifierCell.label.text = @"Bonjour ID";
    self.bonjourIdentifierCell.textField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"bonjourIdentifier"];
    self.bonjourIdentifierCell.textField.placeholder = @"Bonjour Identifier for Server";
    self.bonjourIdentifierCell.textField.delegate = self;
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.bonjourIdentifierCell.textField) {
        [textField resignFirstResponder];
        return YES;
    }

    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    [self updateUserDefaultsFromTextFields];
}

- (void)updateUserDefaultsFromTextFields
{
    [[NSUserDefaults standardUserDefaults] setObject:self.bonjourIdentifierCell.textField.text
                                              forKey:@"bonjourIdentifier"];
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

@end
