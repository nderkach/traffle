//
//  TraffleAppDelegate.h
//  Traffle
//
//  Created by Nikolay Derkach on 18/05/14.
//  Copyright (c) 2014 Nikolay Derkach. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ChatViewController.h"

extern NSString * const SearchFilterDistancePrefsKey;

@interface TraffleAppDelegate : UIResponder <UIApplicationDelegate, ChatViewControllerDelegate>

@property (strong, nonatomic) UIWindow *window;

@end
