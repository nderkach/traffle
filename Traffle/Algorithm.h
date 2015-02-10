//
//  Algorithm.h
//  Traffle
//
//  Created by Nikolay Derkach on 28/05/14.
//  Copyright (c) 2014 Nikolay Derkach. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Parse/Parse.h>

@interface Algorithm : NSObject

+ (void)findMatchWithinRadius:(NSInteger)radius center:(PFGeoPoint*)center completion:(void (^)(PFUser *matchedUser))completion;

@end
