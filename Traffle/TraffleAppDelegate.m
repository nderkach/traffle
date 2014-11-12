//
//  TraffleAppDelegate.m
//  Traffle
//
//  Created by Nikolay Derkach on 18/05/14.
//  Copyright (c) 2014 Nikolay Derkach. All rights reserved.
//

#import <Parse/Parse.h>
#import <Crashlytics/Crashlytics.h>
#import <Appsee/Appsee.h>
#import <Reachability.h>
//#import <Lookback/Lookback.h>

#import "TraffleAppDelegate.h"
#import "DestinationViewController.h"
#import "ListTableViewController.h"

NSString * const SearchFilterDistancePrefsKey = @"SearchFilterDistance";

@implementation TraffleAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [Parse setApplicationId:@"pLpUcJUnlOVUdPaM0O26pFU5y2Jy5w8IcEaaSNvq"
                  clientKey:@"q8pS9tpxAAnj4lqLjfUEYR9df1BgChkhNVzLpqIb"];
    
    [PFFacebookUtils initializeFacebook];

    [Appsee start:@"831bd5c6fa334450909db1d5586fa367"];
    
    [Crashlytics startWithAPIKey:@"86953a5b504233c5b2b755070e77d9702c2af50b"];
    
    // Register for push notifications
    [application registerForRemoteNotificationTypes:
     UIRemoteNotificationTypeBadge |
     UIRemoteNotificationTypeAlert |
     UIRemoteNotificationTypeSound];
    
    // Allocate a reachability object
    Reachability* reach = [Reachability reachabilityWithHostname:@"www.google.com"];
    
    // Here we set up a NSNotification observer. The Reachability that caused the notification
    // is passed in the object parameter
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    
    [reach startNotifier];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],@"firstLaunchPinch",nil]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],@"firstLaunchSwipe",nil]];
    
//    [Lookback_Weak setupWithAppToken:@"Fq2wzq8Tvv5y39ENN"];
    
    return YES;
}

-(void)reachabilityChanged:(NSNotification*)note
{
    Reachability * reach = [note object];
    
    if([reach isReachable])
    {
        NSLog(@"Notification Says Reachable");
        [[UIApplication sharedApplication].keyWindow.rootViewController dismissViewControllerAnimated:YES completion:nil];
    }
    else
    {
        NSLog(@"Notification Says Unreachable");
        UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        UIViewController *vc = [sb instantiateViewControllerWithIdentifier:@"noInternet"];
        vc.modalPresentationStyle = UIModalTransitionStyleCrossDissolve;
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:vc animated:YES completion:nil];

    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [FBAppCall handleDidBecomeActiveWithSession:[PFFacebookUtils session]];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    return [FBAppCall handleOpenURL:url
                  sourceApplication:sourceApplication
                        withSession:[PFFacebookUtils session]];
}

- (void)application:(UIApplication *)application
didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)newDeviceToken {
    // Store the deviceToken in the current installation and save it to Parse.
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation setDeviceTokenFromData:newDeviceToken];
    [currentInstallation saveInBackground];
//    [currentInstallation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
//        if (!error) {
//            // Temp: reset currentinstallation
//            CLSLog(@"current installation object id: %@", currentInstallation.objectId);
//            [PFCloud callFunctionInBackground:@"badgeCount"
//                               withParameters:@{@"currentInstallation": currentInstallation.objectId}
//                                        block:^(NSNumber *count, NSError *error) {
//                                            if (!error) {
//                                                [PFInstallation currentInstallation].badge = [count intValue];
//                                                NSLog(@"[PFInstallation currentInstallation].badge: %ld", (long)[PFInstallation currentInstallation].badge);
//                                                [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[PFInstallation currentInstallation].badge];
//                                            }
//                                        }];
//        } else {
//            CLS_LOG(@"current installation saving failed: %@", error);
//        }
//    }];
}

- (void)didDismissChatViewController:(ChatViewController *)vc
{
}

- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    CLS_LOG(@"Userinfo: %@", userInfo);
    
    // disable in-app alert
    // [PFPush handlePush:userInfo];
    
    if ([userInfo[@"aps"] objectForKey:@"badge"]) {
        NSInteger badgeNumber = [[userInfo[@"aps"] objectForKey:@"badge"] integerValue];
        CLS_LOG(@"Push notification received, set badge count to: %ld", (long)badgeNumber);
        [application setApplicationIconBadgeNumber:badgeNumber];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"pushNotification" object:nil userInfo:userInfo];
    
    if ( application.applicationState == UIApplicationStateActive ) {
        // app was already in the foreground
    } else {
        // app was just brought from background to foreground
        UIStoryboard *mainstoryboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        if ([userInfo[@"type"] isEqualToString:@"message"]) {
            UINavigationController *cnvc = [mainstoryboard instantiateViewControllerWithIdentifier:@"ChatNavigationViewController"];
            PFQuery *query = [PFUser query];
            [query getObjectInBackgroundWithId:userInfo[@"from"] block:^(PFObject *object, NSError *error) {
                ChatViewController *cvc = (ChatViewController*)cnvc.topViewController;
                cvc.recipient = (PFUser *)object;
                [self.window.rootViewController presentViewController:cnvc animated:YES completion:NULL];
            }];
        } else if ([userInfo[@"type"] isEqualToString:@"request"]) {
            DestinationViewController *dvc = [mainstoryboard instantiateViewControllerWithIdentifier:@"DestinationViewController"];
            PFQuery *query = [PFUser query];
            [query getObjectInBackgroundWithId:userInfo[@"from"] block:^(PFObject *object, NSError *error) {
                dvc.matchedUser = (PFUser *)object;
                dvc.incoming = YES;
                [self.window.rootViewController presentViewController:dvc animated:YES completion:NULL];
            }];
        }
    }
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    NSLog(@"Error: %@", error);
}

+ (void)initialize
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *factorySettings = @{SearchFilterDistancePrefsKey: @1000};
    [defaults registerDefaults:factorySettings];
}

@end
