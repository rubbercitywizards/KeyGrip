//
//  RCWGentleErrorNotificationView.m
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

#import "RCWGentleErrorNotificationView.h"
#import <UIKit/UIGestureRecognizerSubclass.h>
@import QuartzCore;

@interface RCWGENVThumb : UIView
@end

@interface RCWThumbGestureRecognizer : UIPanGestureRecognizer
@end

@interface RCWGentleErrorNotificationView ()
@property (nonatomic) BOOL isOpen;
@property (nonatomic) CGPoint centerAtGestureStart;
@property (nonatomic) IBOutlet UIView *thumbView;
@property (nonatomic) IBOutlet UILabel *messageLabel;
@end

@implementation RCWGentleErrorNotificationView

+ (instancetype)viewFromNib
{
    UINib *nib = [UINib nibWithNibName:NSStringFromClass([self class]) bundle:nil];
    NSArray *items = [nib instantiateWithOwner:nil options:nil];
    return items[0];
}

- (IBAction)panned:(RCWThumbGestureRecognizer *)recognizer
{
    CGPoint translation;

    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
            self.centerAtGestureStart = self.center;
            [recognizer setTranslation:self.center inView:self.superview];
            break;
        case UIGestureRecognizerStateChanged:
            translation = [recognizer translationInView:self.superview];
            translation.y = self.center.y;
            CGFloat minX = self.superview.bounds.size.width - self.bounds.size.width / 2;
            if (translation.x < minX) {
                translation.x = minX;
            }

            self.center = translation;
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            if (abs(self.center.x - self.centerAtGestureStart.x) > 20) {
                if (self.isOpen) {
                    [self animateToClosed];
                } else {
                    [self animateToOpen];
                }
            } else {
                if (self.isOpen) {
                    [self animateToOpen];
                } else {
                    [self animateToClosed];
                }
            }
            break;
        default:
            break;
    }
}

- (IBAction)tapped:(UITapGestureRecognizer *)recognizer
{
    [self animateToOpen];
}

- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    if (self.superview) {
        [self centerVerticallyInSuperview];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (self.superview) {
        [self centerVerticallyInSuperview];
    }
}

- (void)centerVerticallyInSuperview
{
    CGRect frame = self.frame;
    frame.origin.y = self.superview.bounds.size.height / 2 - frame.size.height / 2;
    self.frame = frame;
}

- (void)displayError:(NSError *)error
{
    [self displayMessage:error.localizedDescription];
}

- (void)displayMessage:(NSString *)message
{
    self.messageLabel.text = message;

    CGRect frame = self.frame;
    frame.origin.x = self.superview.bounds.size.width;
    self.frame = frame;

    [UIView animateWithDuration:0.1 animations:^{
        CGRect frame = self.frame;
        frame.origin.x = self.superview.bounds.size.width - self.thumbView.bounds.size.width - 15;
        self.frame = frame;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            CGRect frame = self.frame;
            frame.origin.x = self.superview.bounds.size.width - self.thumbView.bounds.size.width;
            self.frame = frame;
        }];
    }];
}

- (void)animateAndRemove
{
    [self animateToClosed];
}

- (void)animateToOpen
{
    [UIView animateWithDuration:0.2 animations:^{
        CGRect frame = self.frame;
        frame.origin.x = self.superview.bounds.size.width - self.bounds.size.width;
        self.frame = frame;
        self.isOpen = YES;
    }];
}

- (void)animateToClosed
{
    [UIView animateWithDuration:0.2 animations:^{
        CGRect frame = self.frame;
        frame.origin.x = self.superview.bounds.size.width;
        self.frame = frame;
        self.isOpen = NO;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end

@implementation RCWThumbGestureRecognizer

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
}

@end
