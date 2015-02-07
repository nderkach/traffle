//
//  DestinationViewController.m
//  Traffle
//
//  Created by Nikolay Derkach on 12/03/14.
//  Copyright (c) 2014 Nikolay Derkach. All rights reserved.
//

#import <Parse/Parse.h>
#import <POP.h>
#import <BBBadgeBarButtonItem.h>
#import <Crashlytics/Crashlytics.h>

#import "DestinationViewController.h"
#import "TraffleAppDelegate.h"
#import "CBG.h"
#import "Constants.h"
#import "Algorithm.h"

//Timer
#define kTimerIntervalInSeconds 1
#define kProfilePicureAnimationDuration 0.5f
#define kProfileTextAnimationDuration 0.5f

@interface DestinationViewController ()

@property (nonatomic) NSInteger searchFilterDistance;
@property (nonatomic, strong) NSMutableArray *requests;
@property(nonatomic, weak) NSTimer *timer;
@property (strong, nonatomic) UIButton *chatButton;
@property (strong, nonatomic) BBBadgeBarButtonItem *barButton;
@property (nonatomic) CGFloat pictureMaskCenterY;
@property (nonatomic) CGFloat profilePictureCenterY;
@property (strong, nonatomic) UIImageView *accepted;
@property (strong, nonatomic) UILabel *hangoutLabel;
@property (strong, nonatomic) UIImageView *acceptedView;
@property (strong, nonatomic) UILabel *coolLabel;
@property (nonatomic, strong) NSURL *userPhotoWebPageURL;
@property (nonatomic, strong) PFObject *conversation;

@end

@implementation DestinationViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    if (self.incoming) {
        PFQuery *query = [PFQuery queryWithClassName:@"Request"];
        [query whereKey:@"accepted" equalTo:[NSNull null]];
        [query whereKey:@"toUser" equalTo:[PFUser currentUser]];
        self.requests = [[NSMutableArray alloc] initWithArray:[query findObjects]];
        
        self.matchedUser = [self.requests lastObject][@"fromUser"];
        [self.matchedUser fetchIfNeeded];
    }
    
    self.hangoutView.delegate = self;
    self.hangoutView.dataSource = self;
    self.hangoutView.scrollOffset = 1;
    
    UIImage *image = [UIImage imageNamed:@"notification_none_icon"];
    self.chatButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.chatButton addTarget:self action:@selector(chatButtonPressed:) forControlEvents:UIControlEventTouchDown];
    self.chatButton.contentMode = UIViewContentModeCenter;
    // 38x36
    self.chatButton.frame = CGRectMake(269, 0, image.size.width+16.0f, image.size.height+16.0f);
    [self.chatButton setImage:image forState:UIControlStateNormal];
    
    self.barButton = [[BBBadgeBarButtonItem alloc] initWithCustomView:self.chatButton];
    
    self.barButton.badgeOriginX = 27.0f;
    self.barButton.badgeOriginY = 6.0f;
    self.barButton.badgeBGColor = kTraffleMainColor;
    self.barButton.badgeMinSize = 18.0f;
    self.barButton.badgeFont = [UIFont fontWithName:@"AvenirNextCondensed-Bold" size:10.0f];
    self.barButton.badgeTextColor = [UIColor blackColor];
    self.barButton.shouldHideBadgeAtZero = YES;
    
    // Set a value for the badge
    self.barButton.badgeValue = [NSString stringWithFormat:@"%ld", (long)[PFInstallation currentInstallation].badge];
    
    [self.view addSubview:self.chatButton];
    
    //Initial stock photos from bundle
    [[CBGStockPhotoManager sharedManager] randomStockPhoto:^(CBGPhotos * photos) {
        [self crossDissolvePhotos:photos withTitle:@""];
    }];
    
    NSLog(@"Fetching photo...");
    
    //Retrieve location and content from Flickr
    [self retrieveLocationAndUpdateBackgroundPhoto];
    
    //Schedule updates
    self.timer = [NSTimer scheduledTimerWithTimeInterval:kTimerIntervalInSeconds target:self selector:@selector(retrieveLocationAndUpdateBackgroundPhoto)userInfo:nil repeats:YES];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.searchFilterDistance = [defaults integerForKey:SearchFilterDistancePrefsKey];
    
//    NSLog(@"defaults = %@", [defaults dictionaryRepresentation]);
    
    NSLog(@"default search distance: %ld", (long)self.searchFilterDistance);

//    self.meetImage.image = [UIImage imageNamed:@"Meet Jenna in Barcelona"];
    

    
//    [self.meetImage setUserInteractionEnabled:YES];
    
    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    
    // Setting the swipe direction.
    [swipeDown setDirection:UISwipeGestureRecognizerDirectionDown];
    
//    self.hangoutLabel.userInteractionEnabled = YES;
    [self.view addGestureRecognizer:swipeDown];
//    [self.hangoutLabel addGestureRecognizer:swipeRight];
    
    // TEMP:
//    [self performSegueWithIdentifier:@"seguePushDemoVC" sender:self];
}

- (void)viewDidLayoutSubviews
{
    self.pictureMaskCenterY = self.pictureMask.center.y;
    self.profilePictureCenterY = self.profilePicture.center.y;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pushNotificationReceived:) name:@"pushNotification" object:nil];
    
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"background_gradient_mask"]];
    
    //        PFQuery *query = [PFQuery queryWithClassName:@"Request"];
    //        [query whereKey:@"accepted" equalTo:[NSNull null]];
    //        NSArray *requests = [query findObjects];
    //
    //        //TODO: FIXME:
    //
    //        for (PFObject *request in requests) {
    //            PFUser *user = request[@"toUser"];
    //
    //            NSLog(@"%@, %@", user.objectId, [PFUser currentUser].objectId);
    //            [user fetchIfNeeded];
    //            if ([user.objectId isEqualToString:[PFUser currentUser].objectId]) {
    //                self.requests = [[NSMutableArray alloc] initWithArray:[query findObjects]];
    //                self.matchedUser = [self.requests lastObject][@"fromUser"];
    //                break;
    //            }
    //        }
    
    self.profilePicture.layer.cornerRadius = self.profilePicture.frame.size.width/2.0;
    self.profilePicture.clipsToBounds = YES;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"firstLaunchSwipe"]) {
        self.acceptView.hidden = NO;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(acceptViewTapped)];
        UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(acceptViewTapped)];
        [self.acceptView addGestureRecognizer:tap];
        [self.acceptView addGestureRecognizer:pinch];
        
        UIImageView *closeButton = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"close_button"]];
        closeButton.frame = CGRectMake(10, 10, 30, 30);
        [self.acceptView addSubview:closeButton];
        
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"firstLaunchSwipe"];
    }
    
    self.pictureMask.hidden = YES;
    self.profilePicture.hidden = YES;
    self.bethereLabel.hidden = YES;
    self.hangoutView.hidden = YES;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self.matchedUser fetchIfNeeded];
    
    [self presentProfilePhoto];
    [self presentProfileText];
}

- (void)pushNotificationReceived:(NSNotification*)aNotification
{
    self.barButton.badgeValue =
    [NSString stringWithFormat:@"%d", [self.barButton.badgeValue intValue] + 1];
}

- (void)chatButtonPressed:(UIButton *)sender
{
    [self performSegueWithIdentifier:@"segueListViewFromDestination" sender:self];
}

- (void)handleSwipe:(UISwipeGestureRecognizer *)swipe {
    
    if (swipe.direction == UISwipeGestureRecognizerDirectionDown) {
        NSLog(@"Swipe Down");

        [self dismissViewControllerAnimated:YES completion:nil];

    }

}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"seguePushChatWhenAccepted"]) {
        UINavigationController *nc = segue.destinationViewController;
        ChatViewController *vc = (ChatViewController *)nc.topViewController;
        vc.conversation = self.conversation;
        vc.delegateModal = self;
    }
}

- (void)getNextIncomingRequest
{
    if ([self.requests count]) {
        self.matchedUser = [self.requests lastObject][@"fromUser"];
        [self.matchedUser fetchIfNeeded];
        [self refreshScreen];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)didDismissChatViewController:(ChatViewController *)vc
{
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.incoming) {
            [self getNextIncomingRequest];
        }
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

-(void)presentProfilePhoto
{
    [self.matchedUser fetchIfNeeded];
    PFFile *file = self.matchedUser[@"Photo"];
    
    [file getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
        if (!error) {
            UIImage *image = [UIImage imageWithData:data];
            //            [self.profilePicture setImage:image forState:UIControlStateNormal];
            // TODO: make a button
            [self.profilePicture setImage:image];
        }
    }];

    
    POPBasicAnimation *pmianim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPositionY];
    pmianim.fromValue = @(-100.0f+self.pictureMaskCenterY-self.profilePictureCenterY);
    pmianim.toValue = @(self.pictureMaskCenterY);
    pmianim.duration = kProfilePicureAnimationDuration;
    pmianim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    pmianim.name = @"PictureMaskAnimation";
    pmianim.delegate = self;
    //
    pmianim.beginTime = (CACurrentMediaTime() + 0.1);
    //
    
    POPBasicAnimation *pianim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPositionY];
    pianim.fromValue = @(-100.0f);
    pianim.toValue = @(self.profilePictureCenterY);
    pianim.duration = kProfilePicureAnimationDuration;
    pianim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    pianim.name = @"ProfilePictureAnimation";
    pianim.delegate = self;
    pianim.beginTime = (CACurrentMediaTime() + 0.1);
    
    [self.pictureMask.layer pop_addAnimation:pmianim forKey:@"positionY"];
    [self.profilePicture.layer pop_addAnimation:pianim forKey:@"positionY"];
}


-(void)pop_animationDidStart:(POPAnimation *)anim
{
    NSLog(@"Hidden? %hhd %hhd %hhd %hhd", self.pictureMask.hidden, self.profilePicture.hidden, self.hangoutView.hidden, self.bethereLabel.hidden);
    
    NSLog(@"Animation: %@", anim.name);
    if ([anim.name isEqualToString:@"PictureMaskAnimation"]) {
        self.pictureMask.hidden = NO;
    } else if ([anim.name isEqualToString:@"ProfilePictureAnimation"]) {
        self.profilePicture.hidden = NO;
    } else if ([anim.name isEqualToString:@"HangoutLabelAnimation"]) {
        self.hangoutView.hidden = NO;
    } else if ([anim.name isEqualToString:@"BethereLabelAnimation"]) {
        self.bethereLabel.hidden = NO;
    } else {
        
    }
}

-(void)presentProfileText
{
    [self.matchedUser fetchIfNeeded];
    if (self.incoming) {
        self.bethereLabel.hidden = YES;
    } else {
//        NSInteger distance = [[PFUser currentUser][@"Location"] distanceInKilometersTo:self.matchedUser[@"Location"]];
//        self.bethereLabel.attributedText = [self getBethereStringWithDistance:distance];
        self.bethereLabel.text = @"";
    }
    
    POPBasicAnimation *mianim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPositionX];
    mianim.fromValue = @(700.0f);
    mianim.toValue = @(self.view.center.x);
    mianim.duration = kProfileTextAnimationDuration;
    mianim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    mianim.delegate = self;
    mianim.name = @"HangoutLabelAnimation";
    mianim.beginTime = (CACurrentMediaTime() + 0.1);
    
    self.hangoutLabel.attributedText = [self getHangoutStringWithName:self.matchedUser[@"Name"] city:self.matchedUser[@"city"] incoming:self.incoming];
    
    [self.hangoutView.layer pop_addAnimation:mianim forKey:@"positionX"];
    
    if (!self.incoming) {
        
        POPBasicAnimation *btanim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPositionX];
        btanim.fromValue = @(700.0f);
        btanim.toValue = @(self.view.center.x);
        btanim.duration = kProfileTextAnimationDuration;
        btanim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        btanim.delegate = self;
        btanim.name = @"BethereLabelAnimation";
        btanim.beginTime = (CACurrentMediaTime() + 0.1);
        
        self.bethereLabel.alpha = 1.0f;
        [self.bethereLabel pop_removeAllAnimations];
        [self.bethereLabel.layer pop_addAnimation:btanim forKey:@"positionX"];
    }
}

-(void)refreshScreen
{
    self.hangoutView.hidden = NO;
    
    // Profile photo animation
    
    POPBasicAnimation *pmianim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPositionY];
    pmianim.fromValue = @(self.pictureMaskCenterY);
    pmianim.toValue = @(-100.0f+self.pictureMaskCenterY-self.profilePictureCenterY);
    pmianim.duration = kProfilePicureAnimationDuration;
    pmianim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    
    POPBasicAnimation *pianim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPositionY];
    pianim.fromValue = @(self.profilePictureCenterY);
    pianim.toValue = @(-100.0f);
    pianim.duration = kProfilePicureAnimationDuration;
    pianim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    pianim.completionBlock = ^(POPAnimation *anim, BOOL finished) {
        self.profilePicture.image = nil;
        [self presentProfilePhoto];
    };
    [self.pictureMask.layer pop_addAnimation:pmianim forKey:@"positionY"];
    [self.profilePicture.layer pop_addAnimation:pianim forKey:@"positionY"];

    // Labels animation

    POPBasicAnimation *moanim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPositionX];
    moanim.fromValue = @(self.view.center.x);
    moanim.toValue = @(700.0f);
    moanim.duration = kProfileTextAnimationDuration;
    moanim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    moanim.completionBlock = ^(POPAnimation *anim, BOOL finished) {
        self.hangoutView.scrollOffset = 1;
        self.hangoutView.scrollEnabled = YES;
        self.bethereLabel.alpha = 1.0f;
        [self presentProfileText];
    };

    if (!self.hangoutView.layer.hidden) {
        [self.hangoutView.layer pop_addAnimation:moanim forKey:@"positionX"];
    } else {
        [self.accepted pop_addAnimation:moanim forKey:@"positionX"];
    }
    
    [self.coolLabel pop_addAnimation:moanim forKey:@"positionX"];
    
    [self.bethereLabel.layer pop_addAnimation:moanim forKey:@"positionX"];
}

- (NSMutableAttributedString *)getHangoutStringWithName:(NSString *)name city:(NSString *)city incoming:(BOOL)incoming
{
    CLS_LOG(@"getHangoutStringWithName: %@, %@", name, city);
    if (!city)
        city = @"Mars";
    UIFont *avenirFontDemiBold = [UIFont fontWithName:@"AvenirNextCondensed-DemiBold" size:33.5f];
    UIFont *avenirFontRegular = [UIFont fontWithName:@"AvenirNextCondensed-Regular" size:33.5f];
    NSDictionary *avenirFontDemiBoldDict = @{NSFontAttributeName: avenirFontDemiBold};
    NSDictionary *avenirFontRegularDict = @{NSFontAttributeName: avenirFontRegular};
    NSMutableAttributedString *cityString = [[NSMutableAttributedString alloc] initWithString:city attributes: avenirFontDemiBoldDict];
    NSMutableAttributedString *nameString = [[NSMutableAttributedString alloc] initWithString:name attributes: avenirFontDemiBoldDict];
    
    NSMutableAttributedString *hangoutString;
    
    if (incoming) {
        
        hangoutString = nameString;
        [hangoutString appendAttributedString:[[NSAttributedString alloc] initWithString:@" wants to hang out." attributes:avenirFontRegularDict]];
        
    } else {

        hangoutString = [[NSMutableAttributedString alloc] initWithString:@"Hang out with " attributes:avenirFontRegularDict];
        
        [hangoutString appendAttributedString:nameString];
        [hangoutString appendAttributedString:[[NSAttributedString alloc] initWithString:@" in " attributes:avenirFontRegularDict]];
        [hangoutString appendAttributedString:cityString];
        [hangoutString appendAttributedString:[[NSAttributedString alloc] initWithString:@"." attributes:avenirFontRegularDict]];
    }
    
    return hangoutString;
}

- (NSMutableAttributedString *)getBethereStringWithDistance:(NSInteger)distance
{
    int time = (int)distance/80;
    NSString *timeString;
    if (time < 1) {
        timeString = @"less than an hour";
    } else if (time == 1) {
        timeString = [NSString stringWithFormat:@"%d hour", (int)distance/80];
    } else {
        timeString = [NSString stringWithFormat:@"%d hours", (int)distance/80];
    }

    NSMutableAttributedString *bethereString = [[NSMutableAttributedString alloc] initWithString:@"Be there in "];

    UIFont *avenirFontDemiBold20 = [UIFont fontWithName:@"AvenirNextCondensed-DemiBold" size:20.5f];
    NSDictionary *avenirFontDemiBold20Dict = [NSDictionary dictionaryWithObject:avenirFontDemiBold20 forKey:NSFontAttributeName];
    NSMutableAttributedString *timeAttrString = [[NSMutableAttributedString alloc] initWithString:timeString attributes: avenirFontDemiBold20Dict];
    
    [bethereString appendAttributedString:timeAttrString];
    [bethereString appendAttributedString:[[NSAttributedString alloc] initWithString:@"."]];
    
    return bethereString;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

//- (IBAction)photoClicked:(id)sender {
//    
//    [UIView animateWithDuration:1.0
//                     animations:^{
//                         self.meetImage.alpha = 0.0f;
//                         if (self.meetImage.image == [UIImage imageNamed:@"Meet Jenna in Barcelona"]) {
//                             self.meetImage.image = [UIImage imageNamed:@"Profile"];
//                         } else {
//                             self.meetImage.image = [UIImage imageNamed:@"Meet Jenna in Barcelona"];
//                         }
//                         self.meetImage.alpha = 1.0f;
//                     }];
//    
//    [self performSegueWithIdentifier:@"seguePushDemoVC" sender:self];
//}

- (IBAction)inviteClicked:(id)sender {
    
    PFObject *request = [PFObject objectWithClassName:@"Request"];
    request[@"fromUser"] = [PFUser currentUser];
    request[@"toUser"] = self.matchedUser;
    
    [request saveInBackground];
}

#pragma mark - Segues

//- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
//{
//    if ([segue.identifier isEqualToString:@"seguePushDemoVC"]) {
//        ChatViewController *vc = segue.destinationViewController;
//        vc.recipient = self.matchedUser;
//    }
//}

- (IBAction)unwindSegue:(UIStoryboardSegue *)sender { }


// Flickr

- (void) retrieveLocationAndUpdateBackgroundPhoto {
    
    [self.matchedUser fetchIfNeeded];
    PFGeoPoint *geoPoint = self.matchedUser[@"Location"];
    CLLocation *location = [[CLLocation alloc] initWithLatitude:geoPoint.latitude longitude:geoPoint.longitude];
    
    //Flickr
    [[CBGFlickrManager sharedManagerWithLocation:location] randomPhotoRequest:^(FlickrRequestInfo * flickrRequestInfo, NSError * error) {
        
        if(!error) {
            self.userPhotoWebPageURL = flickrRequestInfo.userPhotoWebPageURL;
            [self crossDissolvePhotos:flickrRequestInfo.photos withTitle:flickrRequestInfo.userInfo];
        } else {
            
            //Error : Stock photos
            [[CBGStockPhotoManager sharedManager] randomStockPhoto:^(CBGPhotos * photos) {
                [self crossDissolvePhotos:photos withTitle:@""];
            }];
            
            NSLog(@"Flickr: %@", error.description);
        }
    }];
}

- (void) crossDissolvePhotos:(CBGPhotos *) photos withTitle:(NSString *) title {
    [UIView transitionWithView:self.backgroundPhoto duration:1.0f options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        
        self.backgroundPhoto.image = photos.photo;
        self.backgroundPhotoWithImageEffects.image = photos.photoWithEffects;
        [self.copyrightButton setTitle:title forState:UIControlStateNormal];
        
    } completion:NULL];
}

- (IBAction) launchFlickrUserPhotoWebPage:(id) sender {
    if([self.copyrightButton.currentTitle length] > 0) {
        [[UIApplication sharedApplication] openURL:self.userPhotoWebPageURL];
    }
}

- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (motion == UIEventSubtypeMotionShake && !self.incoming) {
        NSLog(@"Device started shaking!");
        
        if (self.hangoutView.currentItemIndex == 1)
            [self swipedLeft];
        else {
            [self getNextMatch];
        }
    }
}

- (NSInteger)numberOfItemsInSwipeView:(SwipeView *)swipeView
{
    return 3;
}

- (void)swipedRight
{
    if (self.incoming) {
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        NSInteger numberOfBadges = currentInstallation.badge;
        if (numberOfBadges > 0) {
            numberOfBadges -= 1;
            [currentInstallation saveEventually];
        }
        
        self.barButton.badgeValue = [NSString stringWithFormat:@"%ld", (long)numberOfBadges];
        
        [[self.requests lastObject] setObject:@YES forKey:@"accepted"];
        [[self.requests lastObject] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            
            [self.requests removeLastObject];
            
            NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSString stringWithFormat:@"%@ accepted you request!", [PFUser currentUser][@"Name"]], @"alert",
                                  @"Increment", @"badge",
                                  @"request", @"type",
                                  [NSString stringWithFormat:@"%@", [PFUser currentUser].objectId], @"from",
                                  nil];
            
            // Now we’ll need to query all saved installations to find those of our recipients
            // Create our Installation query using the self.recipients array we already have
            PFQuery *pushQuery = [PFInstallation query];
            [pushQuery whereKey:@"installationUser" equalTo:self.matchedUser.objectId];
            
            // Send push notification to our query
            PFPush *push = [[PFPush alloc] init];
            [push setQuery:pushQuery];
            [push setData:data];
            [push sendPushInBackground];
            
//            PFInstallation *currentInstallation = [PFInstallation currentInstallation];
//            NSLog(@"%d", currentInstallation.badge);
//            //FIXME: teporarilly
//            if (currentInstallation.badge > 0)
//                currentInstallation.badge -= 1;
//            NSLog(@"%d", currentInstallation.badge);
//            [currentInstallation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
//                if (!error) {
//                    NSLog(@"%d", currentInstallation.badge);
//                    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:currentInstallation.badge];
//                }
//            }];
            
            NSLog(@"Creating a new conversation...");
            
            // TODO: add some notification
            
            PFObject *conversation = [PFObject objectWithClassName:@"Conversation"];
            conversation[@"participants"] = [NSArray arrayWithObjects:[PFUser currentUser], self.matchedUser, nil];
            [conversation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                self.conversation = conversation;
                [self performSegueWithIdentifier:@"seguePushChatWhenAccepted" sender:self];
            }];
        }];
    } else {
        /* send a request */
        PFObject *request = [PFObject objectWithClassName:@"Request"];
        request[@"fromUser"] = [PFUser currentUser];
        request[@"toUser"] = self.matchedUser;
        
        [request saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            // Everything was successful! Reset UI… do other stuff
            // Here’s where we will send the push
            //set our options
            NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSString stringWithFormat:@"%@ wants to hang out!", [PFUser currentUser][@"Name"]], @"alert",
                                  @"Increment", @"badge",
                                  @"request", @"type",
                                  [PFUser currentUser].objectId, @"from",
                                  nil];
            
            // Now we’ll need to query all saved installations to find those of our recipients
            // Create our Installation query using the self.recipients array we already have
            PFQuery *pushQuery = [PFInstallation query];
            [pushQuery whereKey:@"installationUser" equalTo:self.matchedUser.objectId];
            
            // Send push notification to our query
            PFPush *push = [[PFPush alloc] init];
            [push setQuery:pushQuery];
            [push setData:data];
            [push sendPushInBackground];
        }];
    }
    
//    POPBasicAnimation *manim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPositionX];
//    manim.fromValue = @(self.view.center.x);
//    manim.toValue = @(400);
//    manim.duration = 0.5f;
//    manim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
//    manim.completionBlock = ^(POPAnimation *anim, BOOL finished) {
//        self.hangoutLabel.hidden = YES;
//        UIImage *image = [UIImage imageNamed:@"accept_icon"];
//        self.accepted = [[UIImageView alloc] initWithImage:image];
//        self.accepted.frame = CGRectMake(0, self.hangoutLabel.frame.origin.y, image.size.width, image.size.height);
//        [self.view addSubview:self.accepted];
//
//        POPBasicAnimation *canim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPositionX];
//        canim.duration = 0.5f;
//        canim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
//        canim.fromValue = @(0);
//        canim.toValue = @(self.view.center.x);
//        canim.completionBlock = ^(POPAnimation *anim, BOOL finished) {
//            [self.accepted removeFromSuperview];
//            if (self.incoming) {
//
//              [[self.requests lastObject] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
//                  [self.requests removeLastObject];
//                  if ([self.requests count]) {
//                      self.matchedUser = [self.requests lastObject][@"fromUser"];;
//                      [self refreshScreen];
//                  } else {
//                      // no more requests
//                      [self dismissViewControllerAnimated:YES completion:nil];
//                  }
//              }];
//            }
//        };
//        [self.accepted.layer pop_addAnimation:canim forKey:@"confirmed"];
//    };
//    [self.hangoutView.layer pop_addAnimation:manim forKey:@"positionX"];


}

- (void)getNextMatch
{
    if (self.shakeonImageView.alpha) {
        POPBasicAnimation *fianim = [POPBasicAnimation animationWithPropertyNamed:kPOPViewAlpha];
        fianim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        fianim.fromValue = @(1.0);
        fianim.toValue = @(0.0);
        fianim.duration = 0.5f;
        [self.shakeonImageView pop_addAnimation:fianim forKey:@"fade"];
    }
    
    [Algorithm findMatchWithinRadius:(NSInteger)self.searchFilterDistance center:self.center completion:^(PFUser *matchedUser) {
        if (matchedUser) {
            self.matchedUser = matchedUser;
            [self refreshScreen];
        }
        else {
            [self dismissViewControllerAnimated:YES completion:^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"nomatches" object:self userInfo:nil];
            }];
        }
    }];
}

- (void)swipedLeft
{
    if (self.incoming) {
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        NSInteger numberOfBadges = currentInstallation.badge;
        if (numberOfBadges > 0) {
            numberOfBadges -= 1;
            [currentInstallation saveEventually];
        }
        self.barButton.badgeValue = [NSString stringWithFormat:@"%ld", (long)numberOfBadges];
        [[self.requests lastObject] setObject:@NO forKey:@"accepted"];
        [[self.requests lastObject] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            [self.requests removeLastObject];
            [self getNextIncomingRequest];
        }];
    } else {
        
        [self getNextMatch];

        POPBasicAnimation *fanim = [POPBasicAnimation animationWithPropertyNamed:kPOPViewAlpha];
        fanim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        fanim.fromValue = @(1.0);
        fanim.toValue = @(0.0);
        fanim.duration = 2.0f;
        [self.bethereLabel pop_addAnimation:fanim forKey:@"fade"];
    }
}

- (void)swipeViewDidEndDecelerating:(SwipeView *)swipeView
{
    if (self.hangoutView.currentItemIndex != 1) {
        self.hangoutView.scrollEnabled = NO;
    }

    if (self.hangoutView.currentItemIndex == 0) {
        POPBasicAnimation *anim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPositionY];
        anim.duration = 2.0f;
        anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        anim.fromValue = @(self.acceptedView.center.y);
        anim.beginTime = (CACurrentMediaTime() + 1.0);
        anim.toValue = @(-300);
        anim.completionBlock = ^(POPAnimation *anim, BOOL finished) {

        };
        CGRect frame = CGRectInset(self.hangoutView.frame, 20.0f, 0.0f);
        self.coolLabel = [[UILabel alloc] initWithFrame:frame];
        self.coolLabel.textAlignment = NSTextAlignmentCenter;
        self.coolLabel.font = [UIFont fontWithName:@"AvenirNextCondensed-Regular" size:33.5f];
        self.coolLabel.textColor = [UIColor whiteColor];
        self.coolLabel.numberOfLines = 3;
        self.coolLabel.text = [NSString stringWithFormat:@"Cool. We'll let %@ know!", self.matchedUser[@"Name"]];
        [self.hangoutView addSubview:self.coolLabel];
        POPBasicAnimation *canim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPositionY];
        canim.duration = 2.0f;
        canim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        canim.fromValue = @(self.coolLabel.center.y);
        canim.beginTime = (CACurrentMediaTime() + 1.0);
        canim.toValue = @(self.acceptedView.center.y);
        
        canim.completionBlock = ^(POPAnimation *anim, BOOL finished) {
            if (!self.incoming) {
                POPBasicAnimation *fianim = [POPBasicAnimation animationWithPropertyNamed:kPOPViewAlpha];
                fianim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                fianim.fromValue = @(0.0);
                fianim.toValue = @(1.0);
                fianim.duration = 1.0f;
                [self.shakeonImageView pop_addAnimation:fianim forKey:@"fade"];
            }
            
            [self swipedRight];
        };
        
        POPBasicAnimation *fanim = [POPBasicAnimation animationWithPropertyNamed:kPOPViewAlpha];
        fanim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        fanim.fromValue = @(1.0);
        fanim.toValue = @(0.0);
        fanim.duration = 2.0f;
        [self.bethereLabel pop_addAnimation:fanim forKey:@"fade"];
        
        
        [self.acceptedView.layer pop_addAnimation:anim forKey:@"confirmed"];
        if (!self.incoming)
            [self.coolLabel.layer pop_addAnimation:canim forKey:@"cool"];
        else {
            [self swipedRight];
        }

    } else if (self.hangoutView.currentItemIndex == 2) {
        
        [self swipedLeft];
    }
}

- (UIView *)swipeView:(SwipeView *)swipeView viewForItemAtIndex:(NSInteger)index reusingView:(UIView *)view
{
    UIView *newView = [[UIView alloc] initWithFrame:self.hangoutView.bounds];
    
    switch (index) {
        case 0:
        {
            UIImage *image = [UIImage imageNamed:@"accept_icon"];
            self.acceptedView = [[UIImageView alloc] initWithImage:image];
            self.acceptedView.center = newView.center;
            [newView addSubview:self.acceptedView];
            break;
        }
        case 1:
        {
            [self.matchedUser fetchIfNeeded];
            CLS_LOG(@"Matched user: %@ incoming: %hhd", self.matchedUser, self.incoming);
            self.hangoutLabel = [[UILabel alloc] initWithFrame:CGRectInset(newView.frame, 20.0f, 0.0f)];
            self.hangoutLabel.numberOfLines = 2;
            self.hangoutLabel.textAlignment = NSTextAlignmentCenter;
            self.hangoutLabel.textColor = [UIColor whiteColor];
            self.hangoutLabel.tag = 1;
            self.hangoutLabel.font = [UIFont fontWithName:@"AvenirNextCondensed-Regular" size:33.5f];
            self.hangoutLabel.attributedText = [self getHangoutStringWithName:self.matchedUser[@"Name"] city:self.matchedUser[@"city"] incoming:self.incoming];
            [newView addSubview:self.hangoutLabel];
            break;
        }
        case 2:
        {
            break;
        }
    }
    return newView;
}

- (void)acceptViewTapped
{
    POPBasicAnimation *fanim = [POPBasicAnimation animationWithPropertyNamed:kPOPViewAlpha];
    fanim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    fanim.fromValue = @(1.0);
    fanim.toValue = @(0.0);
    fanim.duration = 1.0f;
    fanim.completionBlock = ^(POPAnimation *anim, BOOL finished) {
        self.acceptView.hidden = YES;
    };
    [self.acceptView pop_addAnimation:fanim forKey:@"fade"];
}

@end
