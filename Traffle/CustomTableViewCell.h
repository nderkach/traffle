//
//  CustomTableViewCell.h
//  Traffle
//
//  Created by Nikolay Derkach on 04/02/2015.
//  Copyright (c) 2015 Nikolay Derkach. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CustomTableViewCell : UITableViewCell

- (void)bindData:(PFObject *)conversation_;
- (void)setBadgeText:(NSString *)text;

@property (strong, nonatomic) PFObject *conversation;

@end
