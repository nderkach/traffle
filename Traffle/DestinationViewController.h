//
//  DestinationViewController.h
//  Traffle
//
//  Created by Nikolay Derkach on 12/03/14.
//  Copyright (c) 2014 Nikolay Derkach. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SwipeView.h>

#import "ChatViewController.h"

@interface DestinationViewController : UIViewController <ChatViewControllerDelegate, SwipeViewDataSource, SwipeViewDelegate>

@property (strong, nonatomic) PFUser *matchedUser;
@property (strong, nonatomic) PFGeoPoint *center;
@property (strong, nonatomic) IBOutlet UIImageView *pictureMask;
@property (strong, nonatomic) IBOutlet UIImageView *profilePicture;
@property (strong, nonatomic) IBOutlet SwipeView *hangoutView;
@property (strong, nonatomic) IBOutlet UIImageView *backgroundPhoto;
@property (strong, nonatomic) IBOutlet UILabel *bethereLabel;
@property (strong, nonatomic) IBOutlet UIView *acceptView;
@property (strong, nonatomic) IBOutlet UIImageView *backgroundPhotoWithImageEffects;
@property (strong, nonatomic) IBOutlet UIImageView *shakeonImageView;
@property (strong, nonatomic) IBOutlet UIButton *copyrightButton;

//- (IBAction)photoClicked:(id)sender;
//- (IBAction)inviteClicked:(id)sender;

- (IBAction) launchFlickrUserPhotoWebPage:(id) sender;

@property (nonatomic) BOOL incoming;

@end
