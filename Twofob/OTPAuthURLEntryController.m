//
//  OTPAuthURLEntryController.m
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

#import "OTPAuthURLEntryController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "OTPDefines.h"
#import "OTPAuthURL.h"
#import "NSString+OTPURLArguments.h"
#import "NSData+OTPBase32Encoding.h"
#import "HOTPGenerator.h"
#import "TOTPGenerator.h"
#import "OTPScannerOverlayView.h"
#import "UIColor+MobileColors.h"


@interface OTPAuthURLEntryController () <UITextFieldDelegate, UINavigationControllerDelegate, UIAlertViewDelegate, AVCaptureMetadataOutputObjectsDelegate>

@property (weak, nonatomic) UITextField *activeTextField;
@property (strong, nonatomic) UIBarButtonItem *doneButtonItem;
@property (strong, nonatomic) dispatch_queue_t queue;
@property (strong, nonatomic) AVCaptureSession *avSession;
@property (nonatomic) BOOL handleCapture;

- (void)keyboardWasShown:(NSNotification*)aNotification;
- (void)keyboardWillBeHidden:(NSNotification*)aNotification;
@end

@implementation OTPAuthURLEntryController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = NSLocalizedString(@"Add Token", @"Add Token Navigation Screen Title");
    }
    return self;
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

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)];
    self.navigationItem.rightBarButtonItem = done;
    self.doneButtonItem = done;
    UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
    self.navigationItem.leftBarButtonItem = cancel;
    
  self.accountName.placeholder
    = NSLocalizedString(@"user@example.com",
                        @"Placeholder string for used acccount");
  self.accountNameLabel.text
    = NSLocalizedString(@"Account:",
                        @"Label for Account field");
  self.accountKey.placeholder
    = NSLocalizedString(@"Enter your key",
                        @"Placeholder string for key field");
  self.accountKeyLabel.text
    = NSLocalizedString(@"Key:",
                        @"Label for Key field");
  [self.scanBarcodeButton setTitle:NSLocalizedString(@"Scan Barcode",
                                                     @"Scan Barcode button title")
                          forState:UIControlStateNormal];
  [self.accountType setTitle:NSLocalizedString(@"Time Based",
                                               @"Time Based Account Type")
      forSegmentAtIndex:0];
  [self.accountType setTitle:NSLocalizedString(@"Counter Based",
                                               @"Counter Based Account Type")
      forSegmentAtIndex:1];

  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(keyboardWasShown:)
             name:UIKeyboardDidShowNotification object:nil];

  [nc addObserver:self
         selector:@selector(keyboardWillBeHidden:)
             name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
  self.accountName.text = @"";
  self.accountKey.text = @"";
  self.doneButtonItem
    = self.navigationController.navigationBar.topItem.rightBarButtonItem;
  self.doneButtonItem.enabled = NO;
  self.scrollView.backgroundColor = [UIColor googleBlueBackgroundColor];

  // Hide the Scan button if we don't have a camera that will support video.
  AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
  if (!device) {
    [self.scanBarcodeButton setHidden:YES];
  }
}

- (void)viewWillDisappear:(BOOL)animated {
	self.doneButtonItem = nil;
	self.handleCapture = NO;
	[self.avSession stopRunning];
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification {
  NSDictionary* info = [aNotification userInfo];
  CGFloat offset = 0;
    
  NSValue *sizeValue = info[UIKeyboardFrameBeginUserInfoKey];
  CGSize keyboardSize = [sizeValue CGRectValue].size;
  BOOL isLandscape = UIInterfaceOrientationIsLandscape(self.interfaceOrientation);
  offset = isLandscape ? keyboardSize.width : keyboardSize.height;

  UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, offset, 0.0);
  self.scrollView.contentInset = contentInsets;
  self.scrollView.scrollIndicatorInsets = contentInsets;

  // If active text field is hidden by keyboard, scroll it so it's visible.
  CGRect aRect = self.view.frame;
  aRect.size.height -= offset;
  if (self.activeTextField) {
    CGPoint origin = self.activeTextField.frame.origin;
    origin.y += CGRectGetHeight(self.activeTextField.frame);
    if (!CGRectContainsPoint(aRect, origin) ) {
      CGPoint scrollPoint =
          CGPointMake(0.0, - (self.activeTextField.frame.origin.y - offset));
      [self.scrollView setContentOffset:scrollPoint animated:YES];
    }
  }
}

- (void)keyboardWillBeHidden:(NSNotification*)aNotification {
  UIEdgeInsets contentInsets = UIEdgeInsetsZero;
  self.scrollView.contentInset = contentInsets;
  self.scrollView.scrollIndicatorInsets = contentInsets;
}


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)orientation {
  // Scrolling is only enabled when in landscape.
  if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
    self.scrollView.contentSize = self.view.bounds.size;
  } else {
    self.scrollView.contentSize = CGSizeZero;
  }
}

#pragma mark -
#pragma mark Actions

- (IBAction)accountNameDidEndOnExit:(id)sender {
  [self.accountKey becomeFirstResponder];
}

- (IBAction)accountKeyDidEndOnExit:(id)sender {
  [self done:sender];
}

- (IBAction)done:(id)sender {
  // Force the keyboard away.
  [self.activeTextField resignFirstResponder];

  NSString *encodedSecret = self.accountKey.text;
  NSData *secret = [[NSData alloc] otp_initWithBase32EncodedString:encodedSecret options:OTPDataBase32DecodingCaseInsensitive|OTPDataBase32DecodingIgnoreSpaces];

  if ([secret length]) {
    Class authURLClass = Nil;
    if ([self.accountType selectedSegmentIndex] == 0) {
      authURLClass = [TOTPAuthURL class];
    } else {
      authURLClass = [HOTPAuthURL class];
    }
    NSString *name = self.accountName.text;
    OTPAuthURL *authURL
      = [[authURLClass alloc] initWithSecret:secret
                                         name:name];
    NSString *checkCode = authURL.checkCode;
    if (checkCode) {
      [self.delegate authURLEntryController:self didCreateAuthURL:authURL];
    }
  } else {
    NSString *title = NSLocalizedString(@"Invalid Key",
                                        @"Alert title describing a bad key");
    NSString *message = nil;
    if ([encodedSecret length]) {
      message = [NSString stringWithFormat:
                 NSLocalizedString(@"The key '%@' is invalid.",
                                   @"Alert describing invalid key"),
                 encodedSecret];
    } else {
      message = NSLocalizedString(@"You must enter a key.",
                                  @"Alert describing missing key");
    }
    NSString *button
      = NSLocalizedString(@"Try Again",
                          @"Button title to try again");
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                     message:message
                                                    delegate:nil
                                           cancelButtonTitle:button
                                           otherButtonTitles:nil];
    [alert show];
  }
}

- (IBAction)cancel:(id)sender {
  self.handleCapture = NO;
  [self.avSession stopRunning];
  [self dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)scanBarcode:(UIButton *)sender {
  if (!self.avSession) {
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
      
    AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (captureInput) {
      [session addInput:captureInput];
    } else {
      OTPDevLog(@"AV session error: %@", error);
      sender.enabled = NO;
      return;
    }
      
    dispatch_queue_t queue = dispatch_queue_create("OTPAuthURLEntryController", 0);
    self.queue = queue;
      
    AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
    [session addOutput:output];
    [output setMetadataObjectTypes:@[AVMetadataObjectTypeQRCode]];
    [output setMetadataObjectsDelegate:self queue:queue];

    self.avSession = session;
  }

  AVCaptureVideoPreviewLayer *previewLayer
    = [AVCaptureVideoPreviewLayer layerWithSession:self.avSession];
  [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];

  UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
  NSString *cancelString = NSLocalizedString(@"Cancel", @"Cancel button for taking pictures");
  cancelButton.accessibilityLabel = cancelString;
  [cancelButton setTitle:cancelString forState:UIControlStateNormal];

  UIViewController *previewController = [[UIViewController alloc] init];
  [previewController.view.layer addSublayer:previewLayer];

  CGRect frame = previewController.view.bounds;
  previewLayer.frame = frame;
  OTPScannerOverlayView *overlayView
    = [[OTPScannerOverlayView alloc] initWithFrame:frame];
  [previewController.view addSubview:overlayView];

  [cancelButton addTarget:self
                   action:@selector(cancel:)
         forControlEvents:UIControlEventTouchUpInside];
  [overlayView addSubview:cancelButton];

  NSDictionary *metrics = @{@"margin": @10};
  [overlayView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(>=margin)-[cancelButton]-(>=margin)-|" options:0 metrics:metrics views:NSDictionaryOfVariableBindings(cancelButton)]];
  [overlayView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[cancelButton]-(margin)-|" options:0 metrics:metrics views:NSDictionaryOfVariableBindings(cancelButton)]];
  [overlayView addConstraint:[NSLayoutConstraint constraintWithItem:cancelButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:overlayView attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];

  [self presentViewController:previewController animated:NO completion:NULL];
  self.handleCapture = YES;
  [self.avSession startRunning];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    AVMetadataMachineReadableCodeObject *QRCode = nil;
    for (AVMetadataObject *metadata in metadataObjects) {
        if ([metadata.type isEqualToString:AVMetadataObjectTypeQRCode]) {
            // This will never happen; nobody has ever scanned a QR code... ever
            QRCode = (AVMetadataMachineReadableCodeObject *)metadata;
            break;
        }
    }
    
    if (!QRCode) {
        return;
    }
    
    if (self.handleCapture) {
        self.handleCapture = NO;

        NSString *urlString = QRCode.stringValue;
        NSURL *url = [NSURL URLWithString:urlString];

        dispatch_async(dispatch_get_main_queue(), ^{
            OTPAuthURL *authURL = [OTPAuthURL authURLWithURL:url secret:nil];
            [self.avSession stopRunning];
            
            if (authURL) {
                [self.delegate authURLEntryController:self didCreateAuthURL:authURL];
            } else {
                NSString *title = NSLocalizedString(@"Invalid Barcode",
                                                    @"Alert title describing a bad barcode");
                NSString *message = [NSString stringWithFormat:
                                     NSLocalizedString(@"The barcode '%@' is not a valid "
                                                       @"authentication token barcode.",
                                                       @"Alert describing invalid barcode type."),
                                     urlString];
                NSString *button = NSLocalizedString(@"Try Again",
                                                     @"Button title to try again");
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                                 message:message
                                                                delegate:self
                                                       cancelButtonTitle:button
                                                       otherButtonTitles:nil];
                [alert show];
            }
        });
    }
}

#pragma mark -
#pragma mark UITextField Delegate Methods

- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
    replacementString:(NSString *)string {
  if (textField == self.accountKey) {
    NSMutableString *key
      = [NSMutableString stringWithString:self.accountKey.text];
    [key replaceCharactersInRange:range withString:string];
    self.doneButtonItem.enabled = [key length] > 0;
  }
  return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
  self.activeTextField = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
  self.activeTextField = nil;
}

#pragma mark -
#pragma mark UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView
    didDismissWithButtonIndex:(NSInteger)buttonIndex {
  self.handleCapture = YES;
  [self.avSession startRunning];
}

@end
