//
//  Algorithm.h
//  Pods
//
//  Created by Nikolay Derkach on 16/06/14.
//
//

#import <Foundation/Foundation.h>
#import <Parse/Parse.h>

@interface Algorithm : NSObject

+ (void)findMatchWithinRadius:(NSInteger)radius center:(PFGeoPoint*)center completion:(void (^)(PFUser *matchedUser))completion;

@end
