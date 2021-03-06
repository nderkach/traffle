//
//  CustomTableViewCell.m
//  Traffle
//
//  Created by Nikolay Derkach on 04/02/2015.
//  Copyright (c) 2015 Nikolay Derkach. All rights reserved.
//

#import <Parse/Parse.h>

#import "CustomTableViewCell.h"

@implementation PFImageView (Utility)

// Add a fade animation to images
-(void) setImage:(UIImage *)image {
    if ([self.layer animationForKey:@"KEY_FADE_ANIMATION"] == nil) {
        CABasicAnimation *crossFade = [CABasicAnimation animationWithKeyPath:@"contents"];
        crossFade.duration = 0.6;
        crossFade.fromValue  = (__bridge id)(self.image.CGImage);
        crossFade.toValue = (__bridge id)(image.CGImage);
        crossFade.removedOnCompletion = NO;
        [self.layer addAnimation:crossFade forKey:@"KEY_FADE_ANIMATION"];
    }
    [super setImage:image];
}

@end

@interface CustomTableViewCell ()

@property (strong, nonatomic) UIImageView *backgroundImageView;
@property (strong, nonatomic) UILabel *badgeLabel;
@property (strong, nonatomic) UIImageView *badgeView;
@property (strong, nonatomic) PFImageView *userAvatar;

@property (strong, nonatomic) IBOutlet UILabel *labelDescription;
@property (strong, nonatomic) IBOutlet UILabel *labelLastMessage;
@property (strong, nonatomic) IBOutlet UILabel *labelElapsed;
@property (strong, nonatomic) IBOutlet UILabel *labelCounter;

@end

@implementation CustomTableViewCell

@synthesize labelDescription, labelLastMessage;
@synthesize labelElapsed, labelCounter;

- (void)setBadgeText:(NSString *)text
{
    self.badgeLabel.text = text;
    self.badgeView.hidden = NO;
}

- (void)resetBadge
{
    self.badgeView.hidden = YES;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    UIImage *badgeMask = [UIImage imageNamed:@"chat_new_msg"];
    self.badgeView = [[UIImageView alloc] initWithImage:badgeMask];
    self.badgeView.hidden = YES;
    self.badgeLabel = [[UILabel alloc] init];
    
    self.backgroundColor = [UIColor clearColor];
    self.imageView.image = [UIImage imageNamed:@"big_screen_bg_BLUR"];
    
    self.userAvatar = [[PFImageView alloc] initWithFrame:CGRectMake(19, 27, 53, 53)];
    
    return [super initWithStyle:style reuseIdentifier:reuseIdentifier];
}

-(void)layoutSubviews {
    [super layoutSubviews];
    UIImage *profileMask = [UIImage imageNamed:@"chat_profile_mask"];
    self.backgroundView = [[UIImageView alloc] initWithImage:profileMask];
    self.backgroundView.frame = CGRectMake(16, 25, profileMask.size.width, profileMask.size.height);
    [self insertSubview:self.backgroundView belowSubview:self.userAvatar];
    
    self.userAvatar.layer.cornerRadius = 27;
    self.userAvatar.layer.masksToBounds = YES;
    [self insertSubview:self.userAvatar aboveSubview:self.backgroundView];
    [self.userAvatar loadInBackground];

    UIImage *badgeMask = [UIImage imageNamed:@"chat_new_msg"];
    self.badgeView.frame = CGRectMake(61, 29, badgeMask.size.width, badgeMask.size.height);
    [self addSubview:self.badgeView];
    
    self.badgeLabel.frame = CGRectMake(0.0f, 0.0f, badgeMask.size.width, badgeMask.size.height);
    self.badgeLabel.font = [UIFont fontWithName:@"AvenirNextCondensed-Bold" size:10.0f];
    self.badgeLabel.textColor = [UIColor whiteColor];
    self.badgeLabel.textAlignment = NSTextAlignmentCenter;
    [self.badgeView addSubview:self.badgeLabel];
    
    self.textLabel.frame = CGRectMake(95, self.textLabel.frame.origin.y, 180, self.textLabel.frame.size.height);
    
    self.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (void)bindData:(PFObject *)conversation_
{
    self.conversation = conversation_;

    PFUser *user = [self.conversation[@"participants"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.objectId != %@", [PFUser currentUser].objectId]].firstObject;
    [self.userAvatar setFile:user[@"Photo"]];
    
    UIFont *avenirFont = [UIFont fontWithName:@"AvenirNextCondensed-Regular" size:21.0f];
    UIFont *avenirFontDemiBold = [UIFont fontWithName:@"AvenirNextCondensed-DemiBold" size:21.0f];
    NSDictionary *avenirFontDict = [NSDictionary dictionaryWithObject:avenirFont forKey:NSFontAttributeName];
    NSDictionary *avenirFontDemiBoldDict = [NSDictionary dictionaryWithObject:avenirFontDemiBold forKey:NSFontAttributeName];
    NSMutableAttributedString *finalString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@, ", user[@"Name"]] attributes: avenirFontDict];

    NSMutableAttributedString *cityString;
    if (user[@"city"]) {
        cityString = [[NSMutableAttributedString alloc] initWithString:user[@"city"] attributes: avenirFontDemiBoldDict];
    } else {
        cityString = [[NSMutableAttributedString alloc] initWithString:@"Mars" attributes: avenirFontDemiBoldDict];
    }

    [finalString appendAttributedString:cityString];

    self.textLabel.attributedText = finalString;
    self.textLabel.textColor = [UIColor whiteColor];
    self.textLabel.numberOfLines = 2;
    self.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
}

@end