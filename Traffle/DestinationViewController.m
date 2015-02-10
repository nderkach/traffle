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
#import <MBProgressHUD/MBProgressHUD.h>

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
@property (nonatomic, weak) NSTimer *timer;
@property (strong, nonatomic) UIButton *chatButton;
@property (strong, nonatomic) BBBadgeBarButtonItem *barButton;
@property (nonatomic) CGFloat pictureMaskCenterY;
@property (nonatomic) CGFloat profilePictureCenterY;
@property (strong, nonatomic) UIImageView *accepted;
@property (strong, nonatomic) UILabel *hangoutLabel;
@property (strong, nonatomic) UIImageView *acceptedView;
@property (strong, nonatomic) UILabel *coolLabel;
@property (strong, nonatomic) NSURL *userPhotoWebPageURL;
@property (strong, nonatomic) PFObject *conversation;
@property (strong, nonatomic) MBProgressHUD *progressHud;

@end

@implementation DestinationViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    if (self.incoming) {
        assert([self.requests count]);
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
    
    //Retrieve location and content from Flickr
    [self retrieveLocationAndUpdateBackgroundPhoto];
    
    //Schedule updates
    self.timer = [NSTimer scheduledTimerWithTimeInterval:kTimerIntervalInSeconds target:self selector:@selector(retrieveLocationAndUpdateBackgroundPhoto)userInfo:nil repeats:YES];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.searchFilterDistance = [defaults integerForKey:SearchFilterDistancePrefsKey];
    
    NSLog(@"default search distance: %ld", (long)self.searchFilterDistance);
    
    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    
    // Setting the swipe direction.
    [swipeDown setDirection:UISwipeGestureRecognizerDirectionDown];
    
    [self.view addGestureRecognizer:swipeDown];
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
    
    self.profilePicture.layer.cornerRadius = self.profilePicture.frame.size.width/2.0;
    self.profilePicture.clipsToBounds = YES;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"firstLaunchSwipe"]) {
        self.acceptView.hidden = NO;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(acceptViewTapped)];
        UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(acceptViewTapped)];
        [self.acceptView addGestureRecognizer:tap];
        [self.acceptView addGestureRecognizer:pinch];
        
        UIImageView *closeButton = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"close_button"]];
        closeButton.frame = CGRectMake(20, 20, 20, 20);
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

- (void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super viewWillDisappear:animated];
}

#pragma mark Push notifications

- (void)pushNotificationReceived:(NSNotification*)aNotification
{
    self.barButton.badgeValue = [NSString stringWithFormat:@"%d", [self.barButton.badgeValue intValue] + 1];
}

#pragma mark Swipe delegates and related

- (void)handleSwipe:(UISwipeGestureRecognizer *)swipe {
    if (swipe.direction == UISwipeGestureRecognizerDirectionDown) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)swipedLeft
{
    if (self.incoming) {
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        NSInteger numberOfBadges = currentInstallation.badge;
        if (numberOfBadges > 0) {
            numberOfBadges -= 1;
            [currentInstallation saveInBackground];
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
            [currentInstallation saveInBackground];
        }
        
        self.barButton.badgeValue = [NSString stringWithFormat:@"%ld", (long)numberOfBadges];
        
        [[self.requests lastObject] setObject:@YES forKey:@"accepted"];
        [[self.requests lastObject] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            
            [self.requests removeLastObject];
            
            PFObject *conversation = [PFObject objectWithClassName:@"Conversation"];
            conversation[@"participants"] = [NSArray arrayWithObjects:[PFUser currentUser], self.matchedUser, nil];
            [conversation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                self.conversation = conversation;
                [self performSegueWithIdentifier:@"seguePushChatWhenAccepted" sender:self];
                
                NSDictionary *data = @{@"alert": [NSString stringWithFormat:@"%@ accepted you request!", [PFUser currentUser][@"Name"]],
                                       @"badge": @"Increment",
                                       @"type": @"message",
                                       @"content-available": @1,
                                       @"from": [NSString stringWithFormat:@"%@", [PFUser currentUser].objectId],
                                       @"conversation": [NSString stringWithFormat:@"%@", self.conversation.objectId],
                                       @"text": @"can i haz traffle?"}; // English, motherfucker, do you speak it?
                
                PFQuery *pushQuery = [PFInstallation query];
                [pushQuery whereKey:@"installationUser" equalTo:self.matchedUser.objectId];
                
                PFPush *push = [[PFPush alloc] init];
                [push setQuery:pushQuery];
                [push setData:data];
                [push sendPushInBackground];
            }];
        }];
    } else {
        /* send a request */
        PFObject *request = [PFObject objectWithClassName:@"Request"];
        request[@"fromUser"] = [PFUser currentUser];
        request[@"toUser"] = self.matchedUser;
        
        [request saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            NSDictionary *data = @{@"alert": [NSString stringWithFormat:@"%@ wants to hang out!", [PFUser currentUser][@"Name"]],
                                   @"badge": @"Increment",
                                   @"type": @"request",
                                   @"from": [PFUser currentUser].objectId};
            
            PFQuery *pushQuery = [PFInstallation query];
            [pushQuery whereKey:@"installationUser" equalTo:self.matchedUser.objectId];
            
            PFPush *push = [[PFPush alloc] init];
            [push setQuery:pushQuery];
            [push setData:data];
            [push sendPushInBackground];
        }];
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
            self.hangoutLabel = [[UILabel alloc] initWithFrame:CGRectInset(newView.frame, 20.0f, 0.0f)];
            self.hangoutLabel.numberOfLines = 3;
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

#pragma mark animations and presentation

-(void)presentProfilePhoto
{
    [self.matchedUser fetchIfNeeded];
    PFFile *file = self.matchedUser[@"Photo"];
    
    [file getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
        if (!error) {
            UIImage *image = [UIImage imageWithData:data];
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
    pmianim.beginTime = (CACurrentMediaTime() + 0.1);
    
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
    if ([anim.name isEqualToString:@"PictureMaskAnimation"]) {
        self.pictureMask.hidden = NO;
    } else if ([anim.name isEqualToString:@"ProfilePictureAnimation"]) {
        self.profilePicture.hidden = NO;
    } else if ([anim.name isEqualToString:@"HangoutLabelAnimation"]) {
        self.hangoutView.hidden = NO;
    } else if ([anim.name isEqualToString:@"BethereLabelAnimation"]) {
        self.bethereLabel.hidden = NO;
    } else {
        // void
    }
}

-(void)presentProfileText
{
    [self.matchedUser fetchIfNeeded];
    if (self.incoming) {
        self.bethereLabel.hidden = YES;
    } else {
        self.bethereLabel.text = @""; // temporary disable
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
    [self.progressHud hide:YES];
    self.hangoutView.hidden = NO;
    
    // Profile photo animation
    
    POPBasicAnimation *pmianim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPositionY];
    pmianim.fromValue = @(self.pictureMaskCenterY);
    pmianim.toValue = @(-100.0f+self.pictureMaskCenterY-self.profilePictureCenterY);
    pmianim.duration = kProfilePicureAnimationDuration;
    pmianim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    pmianim.completionBlock = ^(POPAnimation *anim, BOOL finished) {
        self.pictureMask.hidden = YES;
    };
    
    POPBasicAnimation *pianim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPositionY];
    pianim.fromValue = @(self.profilePictureCenterY);
    pianim.toValue = @(-100.0f);
    pianim.duration = kProfilePicureAnimationDuration;
    pianim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    pianim.completionBlock = ^(POPAnimation *anim, BOOL finished) {
        self.profilePicture.hidden = YES;
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
        self.hangoutView.hidden = YES;
        self.hangoutView.hidden = YES;
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

#pragma mark Flickr

- (void) retrieveLocationAndUpdateBackgroundPhoto {
    
    [self.matchedUser fetchIfNeeded];
    PFGeoPoint *geoPoint = self.matchedUser[@"Location"];
    CLLocation *location = [[CLLocation alloc] initWithLatitude:geoPoint.latitude longitude:geoPoint.longitude];
    
    [[CBGFlickrManager sharedManagerWithLocation:location] randomPhotoRequest:^(FlickrRequestInfo * flickrRequestInfo, NSError * error) {
        
        if(!error) {
            self.userPhotoWebPageURL = flickrRequestInfo.userPhotoWebPageURL;
            [self crossDissolvePhotos:flickrRequestInfo.photos withTitle:flickrRequestInfo.userInfo];
        } else {
            [[CBGStockPhotoManager sharedManager] randomStockPhoto:^(CBGPhotos * photos) {
                [self crossDissolvePhotos:photos withTitle:@""];
            }];
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

#pragma mark misc

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

- (void)getNextMatch
{
    self.progressHud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [self.progressHud setLabelText:@"Matching..."];
    [self.progressHud setDimBackground:YES];
    
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
        } else {
            [self dismissViewControllerAnimated:YES completion:^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"nomatches" object:self userInfo:nil];
            }];
        }
    }];
}

- (void)chatButtonPressed:(UIButton *)sender
{
    [self performSegueWithIdentifier:@"segueListViewFromDestination" sender:self];
}

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

@end