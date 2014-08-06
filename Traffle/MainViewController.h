//
//  MainViewController.h
//  Traffle
//
//  Created by Nikolay Derkach on 18/05/14.
//  Copyright (c) 2014 Nikolay Derkach. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Parse/Parse.h>

@interface MainViewController : UIViewController <PFLogInViewControllerDelegate, CLLocationManagerDelegate, RMMapViewDelegate, UIGestureRecognizerDelegate>
@property (strong, nonatomic) IBOutlet UIImageView *pinchingView;
@property (strong, nonatomic) IBOutlet UIImageView *shakeitView;

//- (IBAction)showLookbackSettings:(id)sender;

@end
