//
//  RCWHealthMeter.m
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

#import "RCWHealthMeter.h"

@interface RCWHealthMeter ()
@property (nonatomic, strong) UIView *orb;
@end

@implementation RCWHealthMeter

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.orb = [[UIView alloc] initWithFrame:self.bounds];
        self.orb.layer.masksToBounds = YES;
        self.orb.layer.borderColor = [UIColor darkGrayColor].CGColor;
        self.orb.layer.borderWidth = 1;
        [self addSubview:self.orb];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.orb.layer.cornerRadius = self.bounds.size.width/2;
}

- (void)setHealthy:(BOOL)isHealthy
{
    if (isHealthy) {
        self.orb.backgroundColor = [UIColor greenColor];
    } else {
        self.orb.backgroundColor = [UIColor redColor];
    }
}

- (void)pulseAnimation
{
    [UIView animateWithDuration:0.2 animations:^{
        self.orb.transform = CGAffineTransformMakeScale(1.3, 1.3);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.2 animations:^{
            self.orb.transform = CGAffineTransformIdentity;
        }];
    }];
}


@end
