//
//  RootViewController.m
//
//  Copyright 2011 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not
//  use this file except in compliance with the License.  You may obtain a copy
//  of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
//  License for the specific language governing permissions and limitations under
//  the License.
//

#import "RootViewController.h"
#import "OTPAuthURL.h"
#import "HOTPGenerator.h"
#import "OTPTableViewCell.h"
#import "UIColor+MobileColors.h"
#import "OTPAuthBarClock.h"
#import "TOTPGenerator.h"
#import "GTMLocalizedString.h"

@interface RootViewController ()
@property(nonatomic, readwrite, retain) OTPAuthBarClock *clock;
- (void)showCopyMenu:(UIGestureRecognizer *)recognizer;
@end

@implementation RootViewController
@synthesize delegate = delegate_;
@synthesize clock = clock_;
@synthesize addItem = addItem_;
@synthesize legalItem = legalItem_;

- (void)dealloc {
  [self.clock invalidate];
  self.clock = nil;
  self.delegate = nil;
  self.addItem = nil;
  self.legalItem = nil;
  [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    // On an iPad, support both portrait modes and landscape modes.
    return UIInterfaceOrientationIsLandscape(interfaceOrientation) ||
           UIInterfaceOrientationIsPortrait(interfaceOrientation);
  }
  // On a phone/pod, don't support upside-down portrait.
  return interfaceOrientation == UIInterfaceOrientationPortrait ||
         UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

- (void)viewDidLoad {
  UITableView *view = (UITableView *)self.view;
  view.dataSource = self.delegate;
  view.delegate = self.delegate;
  view.backgroundColor = [UIColor googleBlueBackgroundColor];

  UINavigationItem *navigationItem = self.navigationItem;
  self.clock = [[[OTPAuthBarClock alloc] initWithFrame:CGRectMake(0,0,30,30)
                                                period:[TOTPGenerator defaultPeriod]] autorelease];
  UIBarButtonItem *clockItem
    = [[[UIBarButtonItem alloc] initWithCustomView:clock_] autorelease];
  [navigationItem setLeftBarButtonItem:clockItem animated:NO];
  self.navigationController.toolbar.tintColor = [UIColor googleBlueBarColor];

  UILongPressGestureRecognizer *gesture =
    [[[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                   action:@selector(showCopyMenu:)]
     autorelease];
  [view addGestureRecognizer:gesture];
  UITapGestureRecognizer *doubleTap =
    [[[UITapGestureRecognizer alloc] initWithTarget:self
                                             action:@selector(showCopyMenu:)]
    autorelease];
  doubleTap.numberOfTapsRequired = 2;
  [view addGestureRecognizer:doubleTap];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
  [super setEditing:editing animated:animated];
  self.addItem.enabled = !editing;
  self.legalItem.enabled = !editing;
}

- (void)showCopyMenu:(UIGestureRecognizer *)recognizer {
  BOOL isLongPress =
      [recognizer isKindOfClass:[UILongPressGestureRecognizer class]];
  if ((isLongPress && recognizer.state == UIGestureRecognizerStateBegan) ||
      (!isLongPress && recognizer.state == UIGestureRecognizerStateRecognized)) {
    CGPoint location = [recognizer locationInView:self.view];
    UITableView *view = (UITableView*)self.view;
    NSIndexPath *indexPath = [view indexPathForRowAtPoint:location];
    UITableViewCell* cell = [view cellForRowAtIndexPath:indexPath];
    if ([cell respondsToSelector:@selector(showCopyMenu:)]) {
      location = [view convertPoint:location toView:cell];
      [(OTPTableViewCell*)cell showCopyMenu:location];
    }
  }
}

@end

