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

//static NSString *mapId = @"nderkach.gn10o7i5"; // Adventure
//static NSString *mapId = @"nderkach.id0ea2i4"; // Adventure (realistic)
static NSString *mapId = @"nderkach.id089jd9"; // Elegant
//static NSString *mapId = @"nderkach.id08bc55"; // Elegant (space)

@interface CenterGestureRecognizer : UIPinchGestureRecognizer

- (void)handlePinchGesture;

@property (nonatomic, assign) RMMapView *mapView;
@property (nonatomic, assign) CLLocation *userLocation;

@end

@implementation CenterGestureRecognizer

- (id)initWithMapView:(RMMapView *)mapView {
    if (!mapView) {
        [NSException raise:NSInvalidArgumentException format:@"mapView cannot be nil."];
    }
    
    if ((self = [super initWithTarget:self action:@selector(handlePinchGesture)])) {
        self.mapView = mapView;
    }
    
    return self;
}

- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer {
    return NO;
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer {
    return NO;
}

- (void)handlePinchGesture
{
    [self.mapView setCenterCoordinate:self.mapView.userLocation.coordinate animated:NO];
}

@end


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
    if (isiPhone5) {
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
        if (isiPhone5) {
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
@property (strong, nonatomic) RMAnnotation *dropPin;
@property (nonatomic) CenterGestureRecognizer *pinch;
//@property (strong, nonatomic) NSMutableDictionary *cachedUsers;

@end

@implementation MainViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pushNotificationReceived:) name:@"pushNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nomatches:) name:@"nomatches" object:nil];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"firstLaunchPinch"]) {
        self.shakeitView.hidden = NO;
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
    NSLog(@"Saving searchFilterDistance: %d", self.searchFilterDistance);
    
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:self.searchFilterDistance] forKey:SearchFilterDistancePrefsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self.progressHud hide:YES];
    
    [super viewWillDisappear:animated];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //FIXME:
    //temp
    
//    PFQuery *query = [PFQuery queryWithClassName:@"Request"];
//    [query whereKey:@"objectId" containedIn:@[@"qN5T5WpUsK", @"qFTM6mSout"]];
//    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
//        for (PFObject* object in objects) {
//            object[@"accepted"] = [NSNull null];
//            [object saveInBackground];
//        }
//    }];

    
    //
    //
    
//    if ([PFUser currentUser]) {
//        
//        // cache users with whom you have conversations
//        
//        PFQuery *query = [PFQuery queryWithClassName:@"Conversation"];
//        [query whereKey:@"participants" equalTo:[PFUser currentUser]];
//        [query orderByDescending:@"updatedAt"];
//        
//        [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
//            self.cachedUsers = [[NSMutableDictionary alloc] initWithCapacity:[objects count]];
//            for (id object in objects) {
//                CLS_LOG(@"Existing conversation: %@", (PFObject*)object);
//                PFObject *otherUser = [object[@"participants"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.objectId != %@", [PFUser currentUser].objectId]].firstObject;
//                CLS_LOG(@"Existing conversation with %@", otherUser);
//                [otherUser fetchInBackgroundWithBlock:^(PFObject *object, NSError *error) {
//                    if (!error) {
//                        [self.cachedUsers setObject:object forKey:object.objectId];
//                        CLS_LOG(@"Fetched %@", object.objectId);
//                    }
//                }];
//            }
//        }];
//    }
    
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

    [self.view insertSubview:self.chatButton atIndex:0];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.searchFilterDistance = [defaults integerForKey:SearchFilterDistancePrefsKey];
    
    NSLog(@"Restoring self.searchFilterDistance %ld", (long)self.searchFilterDistance);
    
    [self startSignificantChangeUpdates];
    
    NSLog(@"Setting mapsource...");

    self.mapSource = [[RMMapboxSource alloc] initWithMapID:mapId];
//    self.tileCache = [[RMTileCache alloc] initWithExpiryPeriod:NSIntegerMax];
    
    
    NSLog(@"Search rect radius: %ld", (long)self.searchFilterDistance);
    
    NSLog(@"loading map...");
    
    
    self.mapView = [[RMMapView alloc] initWithFrame:self.view.bounds andTilesource:self.mapSource];
    self.mapView.hideAttribution = YES;
    self.mapView.showLogoBug = NO;
    self.mapView.showsUserLocation = YES;
    self.mapView.userTrackingMode = RMUserTrackingModeFollow;
//    self.mapView.draggingEnabled = NO;
//    self.mapView.zoomingInPivotsAroundCenter = YES;
    
    [self.mapView setDelegate:self];
    
    [self.view insertSubview:self.mapView belowSubview:self.chatButton];
    
    UIImageView *scopeMask = [[UIImageView alloc] initWithFrame:self.view.frame];
    scopeMask.contentMode  = UIViewContentModeScaleAspectFit;
    
    if (isiPhone5) {
        scopeMask.image = [UIImage imageNamed:@"big_screen_scope"];
    } else {
        scopeMask.image = [UIImage imageNamed:@"small_screen_scope"];
    }
    
    [self.view insertSubview:scopeMask belowSubview:self.chatButton];

//    RMSphericalTrapezium rect = [self.mapView latitudeLongitudeBoundingBox];
//    
//    [self.tileCache beginBackgroundCacheForTileSource:self.mapView.tileSource
//                                                    southWest:rect.southWest
//                                                    northEast:rect.northEast
//                                                      minZoom:15.0
//                                                      maxZoom:15.0];
//    self.mapView.tileCache = self.tileCache;
    
    NSLog(@"viewDidLoad... done");
}

//- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
//{
//    return YES;
//    
//    NSArray *validSimultaneousGestures = @[ self.pan ];
////
//    return ([validSimultaneousGestures containsObject:gestureRecognizer] && [validSimultaneousGestures containsObject:otherGestureRecognizer]);
//}

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


- (void)chatButtonPressed:(UIButton *)sender
{
    [self performSegueWithIdentifier:@"segueListView" sender:self];
}


//- (void)pushNotificationReceived:(NSNotification*)aNotification
//{
//    self.barButton.badgeValue =
//        [NSString stringWithFormat:@"%d", [self.barButton.badgeValue intValue] + 1];
//    
//}

- (void)nomatches:(NSNotification*)aNotification
{
    [[[UIAlertView alloc] initWithTitle:@"No matches :("
                                message:@"Sorry, no matches found. Try to increase search radius."
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
}

- (RMMapLayer *)mapView:(RMMapView *)mapView layerForAnnotation:(RMAnnotation *)annotation
{
    RMMarker *marker = [[RMMarker alloc] initWithUIImage:[UIImage imageNamed:@"pin_icon_new"]];
    return marker;
}

- (void)dropLocationPin
{
    
//    NSLog(@"layer size: %f", self.dropPin.layer.frame.size.height);
//    
//    UIImage *pinImage = [UIImage imageNamed:@"pin_icon"];
//    NSLog(@"height: %f", pinImage.size.height);
//    CGPoint pinCenter = CGPointMake(self.mapView.center.x, self.mapView.center.y - pinImage.size.height/2.0f);

//    [self.dropPin.layer pop_removeAllAnimations];
    POPSpringAnimation *anim = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerPositionY];
    anim.fromValue = @(0);
    anim.toValue = @(self.mapView.center.y);
    anim.springSpeed = 8;
    anim.springBounciness = 4;
//    anim.completionBlock = ^(POPAnimation *anim, BOOL finished) {
//        
//        UIImageView *view = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sdny.jpeg"]];
//        view.frame = CGRectMake(self.view.center.x-50, self.view.frame.size.height, 100, 100);
//        view.layer.cornerRadius = 50.0f;
//        view.clipsToBounds = YES;
//        [self.view addSubview:view];
//        
//        POPBasicAnimation *sanim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPositionY];
//        sanim.duration = 4.0f;
//        sanim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
//        sanim.fromValue = @(view.frame.origin.y+50);
//        sanim.toValue = @(view.frame.origin.y-20);
//        [view.layer pop_addAnimation:sanim forKey:@"positionY"];
//    };
    
//    NSLog(@"%@", self.mapView.annotations);
    
//    RMAnnotation *userLocationAnnotation = [self.mapView.annotations firstObject];
//    [userLocationAnnotation.layer pop_addAnimation:anim forKey:@"positionY"];
    

    
//    [UIView animateWithDuration:8.0 animations:^{
//        
////        annotation.layer.opacity = 1.0;
//    
//        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"drop"];
//        animation.toValue = @1.0f;
//        animation.fromValue = @0.0f;
//        animation.duration = 8.0;
//    //    annotation.layer.position = CGPointMake(200, 200);
//        [annotation.layer addAnimation:animation forKey:@"drop"];
//        
//        annotation.layer.opacity = 1.0;
//
//    }];

    
//    [annotation setPosition:CGPointMake(100, 100) animated:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)startSignificantChangeUpdates
{
    // Create the location manager if this object does not
    // already have one.
    if (nil == self.locationManager)
        self.locationManager = [[CLLocationManager alloc] init];
    
    self.locationManager.delegate = self;

    if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [self.locationManager requestAlwaysAuthorization];

    }
    [self.locationManager startMonitoringSignificantLocationChanges];
    //FIXME: temporary update location all the time
//    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
//    [self.locationManager startUpdatingLocation];
}

- (void)afterMapZoom:(RMMapView *)map byUser:(BOOL)wasUserAction
{
    CLLocationCoordinate2D coord2d = [self.mapView pixelToCoordinate:CGPointMake(self.view.center.x + 160.0f, self.view.center.y)];
    CLLocation *coord = [[CLLocation alloc] initWithLatitude:coord2d.latitude longitude:coord2d.longitude];
    CLLocation *userCoord = [[CLLocation alloc] initWithLatitude:self.mapView.centerCoordinate.latitude longitude:self.mapView.centerCoordinate.longitude];
    NSLog(@"scope distance: %f", [coord distanceFromLocation:userCoord]);
    self.searchFilterDistance = [coord distanceFromLocation:userCoord]/1000;
    
    NSLog(@"Coord from: %f %f", userCoord.coordinate.latitude, userCoord.coordinate.longitude);
    NSLog(@"Coord to: %f %f", coord.coordinate.latitude, coord.coordinate.longitude);

    
    NSLog(@"Set search radius to %ld km", (long)self.searchFilterDistance);

}

//- (void)mapViewRegionDidChange:(RMMapView *)mapView
//{
//    UIImage *pinImage = [UIImage imageNamed:@"pin_icon"];
//    CGPoint pinCenter = CGPointMake(self.mapView.center.x, self.mapView.center.y - pinImage.size.height/2.0f);
//    self.dropPin.coordinate = [self.mapView pixelToCoordinate:pinCenter];
//}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLS_LOG("Locations: %@", locations);
    CLLocation *currentLocation = [locations lastObject];
    
    NSLog(@"Location: %f %f", currentLocation.coordinate.latitude, currentLocation.coordinate.longitude);
    
    CLCoordinateRect searchRect = [CLLocation boundingBoxWithCenter:currentLocation.coordinate radius:self.searchFilterDistance * 1000];
    CLLocationCoordinate2D southWest = CLLocationCoordinate2DMake(searchRect.bottomRight.latitude, searchRect.topLeft.longitude);
    CLLocationCoordinate2D northEast = CLLocationCoordinate2DMake(searchRect.topLeft.latitude, searchRect.bottomRight.longitude);
    NSLog(@"Zooming to rect: %f %f, %f %f", southWest.latitude, southWest.longitude, northEast.latitude, northEast.longitude);
    [self.mapView zoomWithLatitudeLongitudeBoundsSouthWest:southWest northEast:northEast animated:YES];
    //                            self.mapView.tileCache = self.tileCache;
    
    self.userLocation = currentLocation;
//    self.mapView.centerCoordinate = currentLocation.coordinate;
    
    //TODO: implement this properly
//    if (self.mapView) {
//        [self.mapView removeGestureRecognizer:self.pinch];
//        self.pinch = [[CenterGestureRecognizer alloc] initWithMapView:self.mapView];
//        [self.mapView addGestureRecognizer:self.pinch];
//    }
    
    /* Location pin */
    
    //    [self.mapView removeAllAnnotations];
    
    //    UIImage *pinImage = [UIImage imageNamed:@"pin_icon"];
    //    NSLog(@"height: %f", pinImage.size.height);
    //    CGPoint pinCenter = CGPointMake(self.mapView.center.x, 0.0f);
    
//    CLLocation *pinLocation = [[CLLocation alloc] initWithLatitude:self.userLocation.coordinate.latitude+10.0f longitude:self.userLocation.coordinate.longitude];
    
//    NSLog(@"Location: %f %f", pinLocation.coordinate.latitude, pinLocation.coordinate.longitude);
    
//    self.dropPin = [[RMAnnotation alloc] initWithMapView:self.mapView
//                                              coordinate:self.mapView.centerCoordinate
//                                                andTitle:@"Center"];
//    
//    [self.mapView addAnnotation:self.dropPin];
    
//    double delayInSeconds = 1.0;
//    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
//    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
//        [self dropLocationPin];
//    });
    
//    UIImage *pinImage = [UIImage imageNamed:@"pin_icon"];
//    CGPoint pinCenter = CGPointMake(self.mapView.center.x, self.mapView.center.y - pinImage.size.height/2.0f);
//    CLLocation *pinLocation = [[CLLocation alloc] initWithLatitude:currentLocation.coordinate.latitude longitude:[self.mapView pixelToCoordinate:pinCenter].longitude];
//    self.dropPin.coordinate = pinLocation.coordinate;
    
}

- (void)updateUserLocation
{
    assert(self.userLocation);
    assert([PFUser currentUser]);
    PFGeoPoint *geoPoint = [PFGeoPoint geoPointWithLocation:self.userLocation];
    
    PFUser *currentUser = [PFUser currentUser];
    currentUser[@"Location"] = geoPoint;
    [[PFUser currentUser] saveInBackground];
    
    NSString *urlStr = [NSString stringWithFormat:@"%@latlng=%f,%f&sensor=true", REVERSE_GEO_CODING_URL, geoPoint.latitude, geoPoint.longitude];
    
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
        
        // now you can use your `dictionary` object
    }];
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


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/



- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (motion == UIEventSubtypeMotionShake) {
        NSLog(@"Device started shaking!");
        
        if (!self.shakeitView.hidden) {
            [self shakeitTapped];
        }
        
        self.progressHud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        [self.progressHud setLabelText:@"Loading..."];
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
                    
                    
                
                } else {
                    
                    [self nomatches:nil];
                
                }
            }
        }];
    }
}

- (void)logInViewController:(PFLogInViewController *)logInController didFailToLogInWithError:(NSError *)error
{
    NSLog(@"%@", error);
}

- (void)logInViewController:(PFLogInViewController *)logInController didLogInUser:(PFUser *)user {
    // user has logged in - we need to fetch all of their Facebook data before we let them in
    
//    PFUser *usr = [PFUser currentUser];
    [self updateUserLocation];
    
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
        NSLog(@"user exists");
        
    } else {
        NSLog(@"new user");
        self.progressHud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        [self.progressHud setLabelText:@"Loading..."];
        [self.progressHud setDimBackground:YES];
        
        // Create a welcome message
        PFQuery *query = [PFUser query];
        [query getObjectInBackgroundWithId:@"db548p2Z2q" block:^(PFObject *object, NSError *error) {
            if (!error) {
                PFObject *conversation = [PFObject objectWithClassName:@"Conversation"];
                conversation[@"participants"] = [NSArray arrayWithObjects:[PFUser currentUser], (PFUser*)object, nil];
                PFObject *unreadNew = [PFObject objectWithClassName:@"Unread"];
                unreadNew[@"conversation"] = conversation;
                unreadNew[@"user"] = [PFUser currentUser];
                unreadNew[@"count"] = @1;
                [unreadNew saveEventually];
                PFObject *unreadMe = [PFObject objectWithClassName:@"Unread"];
                unreadMe[@"conversation"] = conversation;
                unreadMe[@"user"] = object;
                unreadMe[@"count"] = @0;
                [unreadMe saveEventually];
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
                    
//                    [Lookback_Weak lookback].userIdentifier = [PFUser currentUser][@"Name"];
                    
                    [Appsee setUserID:[@[[PFUser currentUser].objectId, [PFUser currentUser][@"Name"], [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey]] componentsJoinedByString:@" "]];
                }];
                
            } else {
                NSLog(@"error: %@", error);
                [self showErrorAlert];
            }
        }];
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
        ListTableViewController *lvc = segue.destinationViewController;
//        lvc.cachedUsers = self.cachedUsers;
    }
}

- (void)dismissSettings {
    UIWindow* window = [[UIApplication sharedApplication] keyWindow];
    [window.rootViewController dismissViewControllerAnimated:YES completion:nil];
}

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
