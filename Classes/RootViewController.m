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
#import "OTPAuthAppDelegate.h"
#import "OTPAuthURL.h"
#import "HOTPGenerator.h"
#import "OTPTableViewCell.h"
#import "UIColor+MobileColors.h"
#import "OTPAuthBarClock.h"
#import "TOTPGenerator.h"
#import "OTPAuthAboutController.h"

@interface RootViewController ()
@property (nonatomic, weak, readwrite) OTPAuthBarClock *clock;
@property (nonatomic, strong) UIBarButtonItem *addItem;
@property (nonatomic, strong) UIBarButtonItem *legalItem;
- (void)showCopyMenu:(UIGestureRecognizer *)recognizer;
@end

@implementation RootViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = NSLocalizedString(@"Google Authenticator", @"Product Name");
    }
    return self;
}

- (void)dealloc {
  [self.clock invalidate];
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

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.navigationController setToolbarHidden:NO animated:animated];
}

- (void)viewDidLoad {
  UITableView *view = self.tableView;
  view.dataSource = self.delegate;
  view.delegate = self.delegate;
  view.backgroundColor = [UIColor googleBlueBackgroundColor];
    
  UIBarButtonItem *flexSpace1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
  UIBarButtonItem *flexSpace2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
  UIBarButtonItem *legalButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Legal Information", @"iPhone Legal Information Button Title") style:UIBarButtonItemStylePlain target:self action:@selector(showLegalInformation:)];
  UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addAuthURL:)];
  self.toolbarItems = @[self.editButtonItem, flexSpace1, legalButton, flexSpace2, addButton];
  self.legalItem = legalButton;
  self.addItem = addButton;

  UINavigationItem *navigationItem = self.navigationItem;
	
	OTPAuthBarClock *clock = [[OTPAuthBarClock alloc] initWithFrame:CGRectMake(0,0,30,30) period:[TOTPGenerator defaultPeriod]];
	UIBarButtonItem *clockItem = [[UIBarButtonItem alloc] initWithCustomView:clock];
	navigationItem.leftBarButtonItem = clockItem;
	self.clock = clock;
	
  self.navigationController.toolbar.tintColor = [UIColor googleBlueBarColor];

  UILongPressGestureRecognizer *gesture =
    [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                   action:@selector(showCopyMenu:)];
  [view addGestureRecognizer:gesture];
  UITapGestureRecognizer *doubleTap =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                             action:@selector(showCopyMenu:)];
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

- (IBAction)showLegalInformation:(id)sender {
    OTPAuthAboutController *controller
    = [[OTPAuthAboutController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

-(IBAction)addAuthURL:(id)sender {
    [(OTPAuthAppDelegate *)[[UIApplication sharedApplication] delegate] addAuthURL:sender];
}

@end

