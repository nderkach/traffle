//
//  MainViewController.m
//  Traffle
//
//  Created by Nikolay Derkach on 18/05/14.
//  Copyright (c) 2014 Nikolay Derkach. All rights reserved.
//

#define REVERSE_GEO_CODING_URL @"https://maps.googleapis.com/maps/api/geocode/json?"

#import <MBProgressHUD.h>
#import <Mapbox.h>
#import <POP.h>
#import <BBBadgeBarButtonItem.h>
#import <Reachability.h>
//#import <LookBack/LookBack.h>
#import <Crashlytics/Crashlytics.h>
#import <Appsee/Appsee.h>

#import "TraffleAppDelegate.h"
#import "MainViewController.h"
#import "DestinationViewController.h"
#import "CLLocation+measuring.h"
#import "Constants.h"
#import "Algorithm.h"
#import "ListTableViewController.h"

#define kMainUserId @"db548p2Z2q"
#define kMapId @"nderkach.l59b1a98"

@interface CustomPFLogInViewController: PFLogInViewController

@property (nonatomic, strong) UIImageView *backgroundView;

@end

@implementation CustomPFLogInViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.logInView.logo = nil;
    self.backgroundView = [[UIImageView alloc] initWithFrame:self.view.frame];
    [self.backgroundView setContentMode:UIViewContentModeScaleAspectFit];
    if (isiPhone5orHigher ) {
        self.backgroundView.image = [UIImage imageNamed:@"big_screen_bg_SHARP"];
    } else {
        self.backgroundView.image = [UIImage imageNamed:@"small_screen_bg_SHARP"];
    }
    [self.logInView insertSubview:self.backgroundView belowSubview:self.logInView.facebookButton];
    
    [self.logInView.facebookButton setBackgroundImage:[UIImage imageNamed:@"fb_login_both_sizes"] forState:UIControlStateNormal];
    [self.logInView.facebookButton setImage:nil forState:UIControlStateNormal];
    [self.logInView.facebookButton setTitle:nil forState:UIControlStateNormal];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(54.0f, self.logInView.facebookButton.frame.origin.y-50.0f, 212.0f, 21.0f)];
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont fontWithName:@"AvenirNextCondensed-Regular" size:20.5f];
    label.textColor = [UIColor whiteColor];
    label.text = @"Adventure is just a tap away.";
    [self.logInView addSubview:label];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [UIView transitionWithView:self.backgroundView duration:3.0f options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        if (isiPhone5orHigher) {
            self.backgroundView.image = [UIImage imageNamed:@"big_screen_bg_BLUR"];
        } else {
            self.backgroundView.image = [UIImage imageNamed:@"small_screen_bg_BLUR"];
        }
        
    } completion:NULL];
}

@end

@interface MainViewController ()

@property (strong, nonatomic) CustomPFLogInViewController *loginViewController;
@property (strong, nonatomic) MBProgressHUD *progressHud;
@property (strong, nonatomic) PFUser *matchedUser;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLLocation *userLocation;
@property (nonatomic) NSInteger searchFilterDistance;
@property (strong, nonatomic) RMMapView *mapView;
@property (strong, nonatomic) RMMapboxSource *mapSource;
@property (strong, nonatomic) RMTileCache *tileCache;
@property (strong, nonatomic) UIButton *chatButton;
@property (strong, nonatomic) BBBadgeBarButtonItem *barButton;
@property (atomic) BOOL matching;

@end

@implementation MainViewController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.matching = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pushNotificationReceived:) name:@"pushNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nomatches:) name:@"nomatches" object:nil];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"firstLaunchPinch"]) {
        self.shakeitView.hidden = NO;

        UIImageView *closeButton = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"close_button"]];
        closeButton.frame = CGRectMake(20, 20, 20, 20);
        [self.shakeitView addSubview:closeButton];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(shakeitTapped)];
        [self.shakeitView addGestureRecognizer:tap];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"firstLaunchPinch"];
    }
    
    self.loginViewController = [[CustomPFLogInViewController alloc] init];
    [self.loginViewController setDelegate:self];
    [self.loginViewController setFields:PFLogInFieldsFacebook];
    [self.loginViewController setFacebookPermissions:@[@"user_likes"]];
    
    // Show the login view controller if necessary
    if (![PFUser currentUser]) {
        [self.navigationController pushViewController:self.loginViewController animated:NO];
    } else {
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        currentInstallation[@"installationUser"] = [[PFUser currentUser] objectId];
        [currentInstallation saveInBackground];
        
        [self updateFbPhoto];
        
        [Crashlytics setUserIdentifier:[PFUser currentUser].objectId];
        [Crashlytics setUserName:[PFUser currentUser][@"Name"]];
        [Crashlytics setUserEmail:[PFUser currentUser][@"email"]];
        
        [Appsee setUserID:[@[[PFUser currentUser].objectId, [PFUser currentUser][@"Name"], [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey]] componentsJoinedByString:@" "]];
        
//        [Lookback_Weak lookback].userIdentifier = [PFUser currentUser][@"Name"];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"Saving searchFilterDistance: %ld", (long)self.searchFilterDistance);
    
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:self.searchFilterDistance] forKey:SearchFilterDistancePrefsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self.progressHud hide:YES];
    
    self.matching = NO;
    
    [super viewWillDisappear:animated];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
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

    [self.view insertSubview:self.chatButton atIndex:0];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.searchFilterDistance = [defaults integerForKey:SearchFilterDistancePrefsKey];
    
    NSLog(@"Restoring self.searchFilterDistance %ld", (long)self.searchFilterDistance);
    
    [self startSignificantChangeUpdates];
    
    self.mapSource = [[RMMapboxSource alloc] initWithMapID:kMapId];
    
    NSLog(@"Search rect radius: %ld", (long)self.searchFilterDistance);
    
    self.mapView = [[RMMapView alloc] initWithFrame:self.view.bounds andTilesource:self.mapSource];
    self.mapView.hideAttribution = YES;
    self.mapView.showLogoBug = NO;
    self.mapView.showsUserLocation = YES;
    self.mapView.userTrackingMode = RMUserTrackingModeFollow;
    self.mapView.maxZoom = 12;
    [self.mapView setZoom:1.0f];
    
    NSLog(@"initial map zoom: %f", self.mapView.zoom);
    
    [self.mapView setDelegate:self];
    
    [self.view insertSubview:self.mapView belowSubview:self.chatButton];
    
    UIImageView *scopeMask = [[UIImageView alloc] initWithFrame:self.view.frame];
    scopeMask.contentMode  = UIViewContentModeScaleAspectFit;
    
    if (isiPhone5orHigher) {
        scopeMask.image = [UIImage imageNamed:@"big_screen_scope"];
    } else {
        scopeMask.image = [UIImage imageNamed:@"small_screen_scope"];
    }
    
    [self.view insertSubview:scopeMask belowSubview:self.chatButton];
}

#pragma mark Overlays

- (void)shakeitTapped
{
    POPBasicAnimation *fanim = [POPBasicAnimation animationWithPropertyNamed:kPOPViewAlpha];
    fanim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    fanim.fromValue = @(1.0);
    fanim.toValue = @(0.0);
    fanim.duration = 1.0f;
    fanim.completionBlock = ^(POPAnimation *anim, BOOL finished) {
        self.shakeitView.hidden = YES;
    };
    [self.shakeitView pop_addAnimation:fanim forKey:@"fade"];
}

- (void)pinchitTapped
{
    POPBasicAnimation *fanim = [POPBasicAnimation animationWithPropertyNamed:kPOPViewAlpha];
    fanim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    fanim.fromValue = @(1.0);
    fanim.toValue = @(0.0);
    fanim.duration = 1.0f;
    fanim.completionBlock = ^(POPAnimation *anim, BOOL finished) {
        self.pinchingView.hidden = YES;
    };
    [self.pinchingView pop_addAnimation:fanim forKey:@"fade"];
}

#pragma mark RMMapView Delegate

- (RMMapLayer *)mapView:(RMMapView *)mapView layerForAnnotation:(RMAnnotation *)annotation
{
    RMMarker *marker = [[RMMarker alloc] initWithUIImage:[UIImage imageNamed:@"pin_icon_new"]];
    return marker;
}

- (void)afterMapZoom:(RMMapView *)map byUser:(BOOL)wasUserAction
{
    NSLog(@"afterMapZoom Map zoom: %f", self.mapView.zoom);
    NSLog(@"self.searchFilterDistance: %ld", (long)self.searchFilterDistance);
    
    CLLocationCoordinate2D coord2d = [self.mapView pixelToCoordinate:CGPointMake(self.view.center.x + 160.0f, self.view.center.y)];
    CLLocation *coord = [[CLLocation alloc] initWithLatitude:coord2d.latitude longitude:coord2d.longitude];
    CLLocation *userCoord = [[CLLocation alloc] initWithLatitude:self.mapView.centerCoordinate.latitude longitude:self.mapView.centerCoordinate.longitude];
    NSLog(@"scope distance: %f", [coord distanceFromLocation:userCoord]);
    self.searchFilterDistance = [coord distanceFromLocation:userCoord]/1000;
    
    NSLog(@"Coord from: %f %f", userCoord.coordinate.latitude, userCoord.coordinate.longitude);
    NSLog(@"Coord to: %f %f", coord.coordinate.latitude, coord.coordinate.longitude);
    
    NSLog(@"Set search radius to %ld km", (long)self.searchFilterDistance);
}

#pragma mark CLLocationManagerDelegate and location methods

- (void)startSignificantChangeUpdates
{
    if (nil == self.locationManager)
        self.locationManager = [[CLLocationManager alloc] init];
    
    self.locationManager.delegate = self;
    
    if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [self.locationManager requestAlwaysAuthorization];
        
    }
    [self.locationManager startMonitoringSignificantLocationChanges];
}

- (void)updateUserLocation
{
    assert(self.userLocation);
    assert([PFUser currentUser]);
    PFGeoPoint *geoPoint = [PFGeoPoint geoPointWithLocation:self.userLocation];
    
    PFUser *currentUser = [PFUser currentUser];
    currentUser[@"Location"] = geoPoint;
    [[PFUser currentUser] saveInBackground];
    
    NSString *urlStr = [NSString stringWithFormat:@"%@latlng=%f,%f&language=en", REVERSE_GEO_CODING_URL, geoPoint.latitude, geoPoint.longitude];
    
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (!data) {
            NSLog(@"%s: sendAynchronousRequest error: %@", __FUNCTION__, connectionError);
            return;
        } else if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            if (statusCode != 200) {
                NSLog(@"%s: sendAsynchronousRequest status code != 200: response = %@", __FUNCTION__, response);
                return;
            }
        }
        
        NSError *parseError = nil;
        NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        if (!dictionary) {
            NSLog(@"%s: JSONObjectWithData error: %@; data = %@", __FUNCTION__, parseError, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            return;
        } else {
            NSArray *results = dictionary[@"results"];
            NSArray *components = [results firstObject][@"address_components"];
            for (NSDictionary *component in components) {
                NSArray *types = component[@"types"];
                if ([types containsObject:@"locality"]) {
                    currentUser[@"city"] = component[@"long_name"];
                    [currentUser saveInBackground];
                }
            }
        }
    }];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation *currentLocation = [locations lastObject];
    
    NSLog(@"Location: %f %f", currentLocation.coordinate.latitude, currentLocation.coordinate.longitude);
    NSLog(@"searchFilterDistance: %ld", self.searchFilterDistance);
    
    CLCoordinateRect searchRect = [CLLocation boundingBoxWithCenter:currentLocation.coordinate radius:self.searchFilterDistance * 1000];
    CLLocationCoordinate2D southWest = CLLocationCoordinate2DMake(searchRect.bottomRight.latitude, searchRect.topLeft.longitude);
    CLLocationCoordinate2D northEast = CLLocationCoordinate2DMake(searchRect.topLeft.latitude, searchRect.bottomRight.longitude);
    NSLog(@"Zooming to rect: %f %f, %f %f", southWest.latitude, southWest.longitude, northEast.latitude, northEast.longitude);
    
    NSLog(@"Map zoom: %f", self.mapView.zoom);
    
    [self.mapView zoomWithLatitudeLongitudeBoundsSouthWest:southWest northEast:northEast animated:NO];
    
    NSLog(@"Map zoom: %f", self.mapView.zoom);
    
    self.userLocation = currentLocation;
    
    if ([PFUser currentUser]) {
        [self updateUserLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"CLLocationManager error: %@", error);
    
    [[[UIAlertView alloc] initWithTitle:@"Unable to identify your location."
                                message:@"Enable Location Services."
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
}

#pragma mark PFLogInViewControllerDelegate and FB methods

- (void)logInViewController:(PFLogInViewController *)logInController didFailToLogInWithError:(NSError *)error
{
    NSLog(@"%@", error);
    if ([[[error userInfo] objectForKey:@"com.facebook.sdk:ErrorLoginFailedReason"] isEqualToString:@"com.facebook.sdk:SystemLoginDisallowedWithoutError"]) {
        
        [[[UIAlertView alloc] initWithTitle:@"Allow Traffle to login with Facebook"
                                    message:@"Enable login in Settings > Facebook > Traffle and retry."
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }
}

- (void)updateFbPhoto {
    [FBRequestConnection startWithGraphPath:@"/me?fields=email,cover,picture.type(large),first_name" completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        if (!error) {
            if (result[@"picture"]) {
                
                NSURL* url = [NSURL URLWithString:result[@"picture"][@"data"][@"url"]];
                NSData *data = [NSData dataWithContentsOfURL:url];
                PFFile *file = [PFFile fileWithData:data];
                
                [file saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                    [[PFUser currentUser] setObject:file forKey:@"Photo"];
                    [[PFUser currentUser] saveInBackground];
                }];
            }
        }
    }];
}

- (void)logInViewController:(PFLogInViewController *)logInController didLogInUser:(PFUser *)user {
    // user has logged in - we need to fetch all of their Facebook data before we let them in
    
    //    PFUser *usr = [PFUser currentUser];
    if (self.userLocation) {
        [self updateUserLocation];
    }
    
    __block NSNumber *totalCount = @(0);
    PFQuery *query = [PFQuery queryWithClassName:@"Unread"];
    [query whereKey:@"user" equalTo:[PFUser currentUser]];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        for (PFObject *object in objects) {
            totalCount = @([totalCount intValue] + [object[@"count"] intValue]);
        }
        self.barButton.badgeValue = [NSString stringWithFormat:@"%@", totalCount];
    }];
    
    [Crashlytics setUserIdentifier:[PFUser currentUser].objectId];
    
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    currentInstallation[@"installationUser"] = [[PFUser currentUser] objectId];
    [currentInstallation saveInBackground];
    
    if (![user isNew]) {
        [self.navigationController popViewControllerAnimated:YES];
        [self updateFbPhoto];
        NSLog(@"user exists");
        
    } else {
        NSLog(@"new user");
        self.progressHud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        [self.progressHud setLabelText:@"Loading..."];
        [self.progressHud setDimBackground:YES];
        
        // Create a welcome message
        PFQuery *query = [PFUser query];
        [query getObjectInBackgroundWithId:kMainUserId block:^(PFObject *object, NSError *error) {
            if (!error) {
                PFObject *conversation = [PFObject objectWithClassName:@"Conversation"];
                conversation[@"participants"] = [NSArray arrayWithObjects:[PFUser currentUser], (PFUser*)object, nil];
                PFObject *unreadNew = [PFObject objectWithClassName:@"Unread"];
                unreadNew[@"conversation"] = conversation;
                unreadNew[@"user"] = [PFUser currentUser];
                unreadNew[@"count"] = @1;
                [unreadNew saveInBackground];
                PFObject *unreadMe = [PFObject objectWithClassName:@"Unread"];
                unreadMe[@"conversation"] = conversation;
                unreadMe[@"user"] = object;
                unreadMe[@"count"] = @0;
                [unreadMe saveInBackground];
                [conversation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                    if (!error) {
                        PFObject *message = [PFObject objectWithClassName:@"Message"];
                        message[@"conversation"] = conversation;
                        message[@"sender"] = (PFUser*)object;
                        message[@"recipient"] = [PFUser currentUser];
                        message[@"text"] = [NSString stringWithFormat:@"Hey, %@. Welcome to traffle!", [PFUser currentUser][@"Name"]];
                        [message saveInBackground];
                    }
                }];
            }
        }];
        
        // Get user's personal information
        [FBRequestConnection startWithGraphPath:@"/me/likes?limit=1000" completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (!error) {
                
                if (result[@"data"]) {
                    
                    NSMutableArray *fbLikes = [[NSMutableArray alloc] init];
                    for (FBGraphObject* like in result[@"data"]) {
                        [fbLikes addObject:like[@"id"]];
                    }
                    
                    [[PFUser currentUser] setObject:fbLikes forKey:@"fbLikes"];
                    [[PFUser currentUser] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                        [MBProgressHUD hideHUDForView:self.view animated:YES];
                        [self.navigationController popViewControllerAnimated:YES];
                    }];
                }
            } else {
                NSLog(@"error: %@", error);
                [self showErrorAlert];
            }
        }];
        
        [FBRequestConnection startWithGraphPath:@"/me?fields=email,cover,picture.type(large),first_name" completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (!error) {
                if (result[@"email"]) {
                    
                    [[PFUser currentUser] setObject:result[@"email"] forKey:@"email"];
                    [[PFUser currentUser] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                        [Crashlytics setUserEmail:[PFUser currentUser][@"email"]];
                    }];
                }
                
                if (result[@"picture"]) {
                    
                    NSURL* url = [NSURL URLWithString:result[@"picture"][@"data"][@"url"]];
                    NSData *data = [NSData dataWithContentsOfURL:url];
                    PFFile *file = [PFFile fileWithData:data];
                    
                    [file saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                        [[PFUser currentUser] setObject:file forKey:@"Photo"];
                        [[PFUser currentUser] saveInBackground];
                    }];
                }
                
                [[PFUser currentUser] setObject:result[@"first_name"] forKey:@"Name"];
                [[PFUser currentUser] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                    [Crashlytics setUserName:[PFUser currentUser][@"Name"]];
                    
                    // [Lookback_Weak lookback].userIdentifier = [PFUser currentUser][@"Name"];
                    
                    [Appsee setUserID:[@[[PFUser currentUser].objectId, [PFUser currentUser][@"Name"], [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey]] componentsJoinedByString:@" "]];
                }];
                
            } else {
                NSLog(@"error: %@", error);
                [self showErrorAlert];
            }
        }];
    }
}

#pragma mark misc

- (void)chatButtonPressed:(UIButton *)sender
{
    [self performSegueWithIdentifier:@"segueListView" sender:self];
}

- (void)pushNotificationReceived:(NSNotification*)aNotification
{
    self.barButton.badgeValue =
        [NSString stringWithFormat:@"%d", [self.barButton.badgeValue intValue] + 1];
    
}

- (void)nomatches:(NSNotification*)aNotification
{
    [[[UIAlertView alloc] initWithTitle:@"No matches :("
                                message:@"Sorry, no matches found. Try to increase search radius."
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
}

- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (motion == UIEventSubtypeMotionShake && !self.matching) {
        NSLog(@"Device started shaking!");
        
        self.matching = YES;
        
        if (!self.shakeitView.hidden) {
            [self shakeitTapped];
        }
        
        self.progressHud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        [self.progressHud setLabelText:@"Matching..."];
        [self.progressHud setDimBackground:YES];
        
        CAKeyframeAnimation * anim = [ CAKeyframeAnimation animationWithKeyPath:@"transform" ] ;
        anim.values = @[ [ NSValue valueWithCATransform3D:CATransform3DMakeTranslation(-5.0f, 0.0f, 0.0f) ], [ NSValue valueWithCATransform3D:CATransform3DMakeTranslation(5.0f, 0.0f, 0.0f) ] ] ;
        anim.autoreverses = YES ;
        anim.repeatCount = 2.0f ;
        anim.duration = 0.07f ;
        
        [self.view.layer addAnimation:anim forKey:nil];
        
        [Algorithm findMatchWithinRadius:(NSInteger)self.searchFilterDistance center:[PFGeoPoint geoPointWithLatitude:self.mapView.centerCoordinate.latitude longitude:self.mapView.centerCoordinate.longitude] completion:^(PFUser *matchedUser) {
            if (matchedUser) {
                self.matchedUser = matchedUser;
                [self performSegueWithIdentifier:@"showDestinationsFromMain" sender:self];
            } else {
                [self.progressHud hide:YES];
                if (![[NSUserDefaults standardUserDefaults] objectForKey:@"firstNomatch"]) {
                    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],@"firstNomatch",nil]];
                }
                
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"firstNomatch"]) {
                    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],@"firstNomatch",nil]];
                    self.pinchingView.alpha = 0.0f;
                    self.pinchingView.hidden = NO;
                    UIImageView *closeButton = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"close_button"]];
                    closeButton.frame = CGRectMake(20, 20, 20, 20);
                    [self.pinchingView addSubview:closeButton];
                    
                    POPBasicAnimation *fanim = [POPBasicAnimation animationWithPropertyNamed:kPOPViewAlpha];
                    fanim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                    fanim.fromValue = @(0.0);
                    fanim.toValue = @(1.0);
                    fanim.duration = 1.0f;
                    fanim.completionBlock = ^(POPAnimation *anim, BOOL finished) {
                        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pinchitTapped)];
                        UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchitTapped)];
                        [self.pinchingView addGestureRecognizer:tap];
                        [self.pinchingView addGestureRecognizer:pinch];

                    };
                    [self.pinchingView pop_addAnimation:fanim forKey:@"fade"];
                    [self increaseScope:0.5f];
                
                } else {
                    
                    [self nomatches:nil];
                    [self increaseScope:0.5f];
                }
            }
        }];
    }
}

- (void)increaseScope:(float)factor {
    if (self.mapView.zoom >= 2.0f) {
        [self.mapView zoomByFactor:0.5f near:self.mapView.center animated:YES];
    } else {
        self.mapView.zoom = 1.0f;
    }
}

- (void)showErrorAlert {
    [[[UIAlertView alloc] initWithTitle:@"Something went wrong"
                                message:@"We were not able to create your profile. Please try again."
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"showDestinationsFromMain"]) {
        UINavigationController *navigationViewController = segue.destinationViewController;
        DestinationViewController *destinationViewController = (DestinationViewController*)navigationViewController.topViewController;
        destinationViewController.matchedUser = self.matchedUser;
        destinationViewController.incoming = NO;
        destinationViewController.center = [PFGeoPoint geoPointWithLatitude:self.mapView.centerCoordinate.latitude longitude:self.mapView.centerCoordinate.longitude];
    } else if ([segue.identifier isEqualToString:@"segueListView"]) {
        // do nothing
    }
}

//- (void)dismissSettings {
//    UIWindow* window = [[UIApplication sharedApplication] keyWindow];
//    [window.rootViewController dismissViewControllerAnimated:YES completion:nil];
//}

//- (IBAction)showLookbackSettings:(id)sender
//{
//        UIViewController *settings = [LookbackSettingsViewController_Weak settingsViewController];
//        if(!settings)
//            return;
//        settings.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissSettings)];
//        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
//        [self presentViewController:nav animated:YES completion:nil];
//}


@end
