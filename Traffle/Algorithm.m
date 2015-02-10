//
//  Algorithm.m
//  Traffle
//
//  Created by Nikolay Derkach on 28/05/14.
//  Copyright (c) 2014 Nikolay Derkach. All rights reserved.
//

#import "Algorithm.h"

#import <UIKit/UIKit.h>
#import <Crashlytics/Crashlytics.h>

@implementation Algorithm

+ (void)findMatchWithinRadius:(NSInteger)radius center:(PFGeoPoint*)center completion:(void (^)(PFUser *matchedUser))completion
{
    PFUser *currentUser = [PFUser currentUser];
    [currentUser refreshInBackgroundWithBlock:^(PFObject *object, NSError *error) {}];
    NSArray *myLikes = currentUser[@"fbLikes"];
    
    PFQuery *query = [PFUser query];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            NSMutableDictionary *rankings = [[NSMutableDictionary alloc] init];
            
            for (PFUser *user in objects) {
                if (user[@"Location"] && user[@"city"] &&
                    ![user.objectId isEqualToString:[PFUser currentUser].objectId] &&
                    [user[@"Location"] distanceInKilometersTo:center] < radius &&
                    ![currentUser[@"ignoredUsers"] containsObject:user.objectId]) {
                    NSMutableSet *intersection = [NSMutableSet setWithArray:myLikes];
                    [intersection intersectSet:[NSSet setWithArray:user[@"fbLikes"]]];
                    CLSLog(@"Match: Number of intersections: %@ intersection: %@", [NSNumber numberWithUnsignedInteger: [intersection count]], intersection);
                    [rankings setObject:@{ @"size": [NSNumber numberWithUnsignedInteger: [intersection count]], @"intersection": intersection } forKey:user.objectId];
                }
            }
            
            if ([rankings count]) {
                NSArray *keysByFrequency = [rankings keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary* obj1, NSDictionary* obj2) {
                    return [obj2[@"size"] compare:obj1[@"size"]];
                }];
                
//                NSString *randomId = keysByFrequency[arc4random_uniform([keysByFrequency count])];
                NSString *matchedId = [keysByFrequency firstObject];
                
                NSMutableArray *ignoredUsers = currentUser[@"ignoredUsers"];
                if (!ignoredUsers)
                    ignoredUsers = [[NSMutableArray alloc] init];
                [ignoredUsers addObject:matchedId];
                currentUser[@"ignoredUsers"] = ignoredUsers;
                [currentUser saveInBackground];
                
                PFQuery *query = [PFUser query];
                [query getObjectInBackgroundWithId:matchedId block:^(PFObject *object, NSError *error) {
                    if (!error && completion) {
                        completion( (PFUser*)object );
                    }
                }];
            } else {
                completion(nil);
            }
        } else {
            NSLog(@"Error: %@ %@", error, [error userInfo]);
        }
    }];
}

@end