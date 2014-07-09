//
//  Algorithm.m
//  Pods
//
//  Created by Nikolay Derkach on 16/06/14.
//
//

#import "Algorithm.h"

#import <UIKit/UIKit.h>
#import <Crashlytics/Crashlytics.h>

@implementation Algorithm

+ (void)findMatchWithinRadius:(NSInteger)radius center:(PFGeoPoint*)center completion:(void (^)(PFUser *matchedUser))completion
{
    PFUser *currentUser = [PFUser currentUser];
    NSArray *myLikes = currentUser[@"fbLikes"];
    
    PFQuery *query = [PFUser query];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            NSMutableDictionary *rankings = [[NSMutableDictionary alloc] init];
            
            for (PFUser *user in objects) {
                if (user[@"Location"] && user[@"city"] &&
                    ![user.objectId isEqualToString:[PFUser currentUser].objectId] &&
                    [user[@"Location"] distanceInKilometersTo:center] < radius &&
                    ![[[NSUserDefaults standardUserDefaults] objectForKey:@"declinedUsers"] containsObject:user.objectId]) {
                    NSLog(@"%@", user.objectId);
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
                
                NSString *firstId = [keysByFrequency firstObject];
                
                PFQuery *query = [PFUser query];
                [query getObjectInBackgroundWithId:firstId block:^(PFObject *object, NSError *error) {
                    if (!error && completion) {
                        NSMutableArray *declinedUsers = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"declinedUsers"]];
                        [declinedUsers addObject:object.objectId];
                        [[NSUserDefaults standardUserDefaults] setObject:declinedUsers forKey:@"declinedUsers"];                        [[NSUserDefaults standardUserDefaults] synchronize];
                        
                        completion( (PFUser*)object );
                    }
                }];
            } else {
                completion(nil);
            }
        } else {
            // Log details of the failure
            NSLog(@"Error: %@ %@", error, [error userInfo]);
        }
    }];
}

@end