//
//  ListTableViewController.m
//  Traffle
//
//  Created by Nikolay Derkach on 28/05/14.
//  Copyright (c) 2014 Nikolay Derkach. All rights reserved.
//

#import <POP.h>
#import <Crashlytics/Crashlytics.h>

#import "ListTableViewController.h"
#import "ChatViewController.h"
#import "DestinationViewController.h"
#import "Constants.h"

static int delay = 0.0;

@interface CustomPFTableViewCell : PFTableViewCell

@property (strong, nonatomic) UIImageView *backgroundImageView;
@property (strong, nonatomic) UILabel *badgeLabel;
@property (strong, nonatomic) UIImageView *badgeView;
@property (strong, nonatomic) PFUser *user;

@end

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

@implementation CustomPFTableViewCell

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
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    return [super initWithStyle:style reuseIdentifier:reuseIdentifier];
}

-(void)layoutSubviews {
    [super layoutSubviews];
    
    UIImage *profileMask = [UIImage imageNamed:@"chat_profile_mask"];
    self.backgroundView = [[UIImageView alloc] initWithImage:profileMask];
    self.backgroundView.frame = CGRectMake(16, 25, profileMask.size.width, profileMask.size.height);
    [self insertSubview:self.backgroundView belowSubview:self.imageView];
    
    self.imageView.frame = CGRectMake(19, 27, 53, 53);
    self.imageView.layer.cornerRadius = 27;
    self.imageView.layer.masksToBounds = YES;
    [self addSubview:self.imageView];

    UIImage *badgeMask = [UIImage imageNamed:@"chat_new_msg"];
    self.badgeView.frame = CGRectMake(61, 29, badgeMask.size.width, badgeMask.size.height);
    [self addSubview:self.badgeView];
    
    self.badgeLabel.frame = CGRectMake(0.0f, 0.0f, badgeMask.size.width, badgeMask.size.height);
    self.badgeLabel.font = [UIFont fontWithName:@"AvenirNextCondensed-Bold" size:10.0f];
    self.badgeLabel.textColor = [UIColor whiteColor];
    self.badgeLabel.textAlignment = NSTextAlignmentCenter;
    [self.badgeView addSubview:self.badgeLabel];
    
    self.textLabel.frame = CGRectMake(95, self.textLabel.frame.origin.y, self.textLabel.frame.size.width, self.textLabel.frame.size.height);
}

@end

@interface ListTableViewController ()

@property (strong, nonatomic) NSMutableArray *users;

@end

@implementation ListTableViewController

- (id)initWithCoder:(NSCoder *)aCoder
{
    self = [super initWithCoder:aCoder];
    if (self) {
        // The key of the PFObject to display in the label of the default cell style
        self.textKey = @"objectId";
        
        // The title for this table in the Navigation Controller.
//        self.title = @"Chats";
        
        // Whether the built-in pull-to-refresh is enabled
//        self.pullToRefreshEnabled = YES;
        
        // Whether the built-in pagination is enabled
//        self.paginationEnabled = YES;
        
        // The number of objects to show per page
//        self.objectsPerPage = 5;
    }
    return self;
}

- (void)didDismissChatViewController:(ChatViewController *)vc
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
//    UIImage *image = [UIImage imageNamed:@"eye_icon"];
//    
//    self.showUnreadRequestsButton.imageEdgeInsets = UIEdgeInsetsMake(0., self.showUnreadRequestsButton.frame.size.width - (image.size.width + 15.), 0., 0.);
//    self.showUnreadRequestsButton.titleEdgeInsets = UIEdgeInsetsMake(0., 0., 0., image.size.width);
//    [self.showUnreadRequestsButton setImage:image forState:UIControlStateNormal];
    
    if (isiPhone5) {
        self.tableView.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"big_screen_bg_BLUR"]];
    } else {
        self.tableView.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"small_screen_bg_BLUR"]];
    }

    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    self.tableView.separatorColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"separator"]];
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    /* generate a fake requests to myself */
    
//    if (![[PFUser currentUser].objectId isEqualToString:@"teApK6wywU"]) {
//        
//        PFQuery *query = [PFUser query];
//        PFUser *suser = (PFUser*)[query getObjectWithId:@"teApK6wywU"];
//        NSLog(@"%@", [PFUser currentUser]);
//        
//        PFObject *request = [PFObject objectWithClassName:@"Request"];
//        request[@"fromUser"] = [PFUser currentUser];
//        request[@"toUser"] = suser;
//        
//        [request saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
//            // Everything was successful! Reset UI… do other stuff
//            // Here’s where we will send the push
//            //set our options
//            NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:
//                                  [NSString stringWithFormat:@"%@ wants to hang out!", [PFUser currentUser][@"Name"]], @"alert",
//                                  @"Increment", @"badge",
//                                  @"request", @"type",
//                                  nil];
//            
//            // Now we’ll need to query all saved installations to find those of our recipients
//            // Create our Installation query using the self.recipients array we already have
//            PFQuery *pushQuery = [PFInstallation query];
//            [pushQuery whereKey:@"installationUser" equalTo:suser.objectId];
//            
//            // Send push notification to our query
//            PFPush *push = [[PFPush alloc] init];
//            [push setQuery:pushQuery];
//            [push setData:data];
//            [push sendPushInBackground];
//            
//        }];
//    }

}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    
    [super viewWillDisappear:animated];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    PFQuery *query = [PFQuery queryWithClassName:@"Request"];
    [query whereKey:@"accepted" equalTo:[NSNull null]];
    [query whereKey:@"toUser" equalTo:[PFUser currentUser]];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if ([objects count]) {
            UIFont *avenirFont = [UIFont fontWithName:@"AvenirNextCondensed-Regular" size:17.5f];
            UIFont *avenirFontDemiBold = [UIFont fontWithName:@"AvenirNextCondensed-DemiBold" size:17.5f];
            NSDictionary *avenirFontDict = @{NSFontAttributeName: avenirFont,
                                             NSForegroundColorAttributeName : [UIColor blackColor]};
            NSDictionary *avenirFontDemiBoldDict = @{NSFontAttributeName: avenirFontDemiBold,
                                                     NSForegroundColorAttributeName : kTraffleMainColor};
            NSMutableAttributedString *finalString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%lu ", (unsigned long)[objects count]] attributes: avenirFontDemiBoldDict];
            NSMutableAttributedString *notString;
            
            if ([objects count] == 1) {
                notString = [[NSMutableAttributedString alloc] initWithString:@"new invitation" attributes:avenirFontDict];
            } else {
                notString = [[NSMutableAttributedString alloc] initWithString:@"new invitations" attributes:avenirFontDict];
            }
            [finalString appendAttributedString:notString];
            [self.showUnreadRequestsButton setAttributedTitle:finalString forState:UIControlStateNormal];
            self.showUnreadRequestsButton.hidden = NO;
        }
        else {
            self.showUnreadRequestsButton.hidden = YES;
        }
    }];
    
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"Displaying row: %ld", (long)[indexPath row]);
}

//-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
//{
//    return self.headerView;
//}
//
//-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
//{
////    return self.headerView.frame.size.height;
//    return 65.0f;
//}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 100.0f;
}

//- (void)objectsDidLoad:(NSError *)error
//{
//    [super objectsDidLoad:error];
//    
//    CGFloat toValue = CGRectGetMidX(self.view.bounds);
//    
//    NSUInteger index = 0;
//    for (UITableViewCell *cell in self.tableView.visibleCells) {
//    
//    POPSpringAnimation *onscreenAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerPositionX];
//        onscreenAnimation.fromValue = @(-toValue);
//        onscreenAnimation.toValue = @(toValue);
//        onscreenAnimation.springBounciness = 5.f;
//        onscreenAnimation.beginTime = (CACurrentMediaTime() + 0.1 * index);
//        onscreenAnimation.delegate = self;
//        [cell.layer pop_addAnimation:onscreenAnimation forKey:onscreenAnimation.name];
//        index++;
//    }
//    
//}

-(void)pop_animationDidStart:(POPAnimation *)anim
{
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:[anim.name intValue] inSection:0]];
    cell.hidden = NO;
}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Override to customize what kind of query to perform on the class. The default is to query for
// all objects ordered by createdAt descending.
- (PFQuery *)queryForTable {
    PFQuery *query = [PFQuery queryWithClassName:@"Conversation"];
    [query whereKey:@"participants" equalTo:[PFUser currentUser]];
    [query orderByDescending:@"updatedAt"];
    return query;
}

//- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
//    CGRect frame = tableView.frame;
//    
//    UIButton *addButton = [[UIButton alloc] initWithFrame:CGRectMake(10, 10, frame.size.width, frame.size.height)];
//    [addButton setTitle:@"4 unread requets" forState:UIControlStateNormal];
//
//    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
//    [headerView addSubview:addButton];
//    
//    return headerView;
//}


- (void)configureCellAsync:(CustomPFTableViewCell *)cell user:(PFUser *)user index:(NSUInteger)index
{
    CLS_LOG(@"configureCellAsync %@ at index %lu...", user, (unsigned long)index);
    
    cell.user = user;
    
    PFFile *thumbnail = user[@"Photo"];
    
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
    
    cell.textLabel.attributedText = finalString;
    cell.textLabel.textColor = [UIColor whiteColor];
    
    [thumbnail getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
        [cell.imageView setImage:[UIImage imageWithData:data]];
        [cell.imageView setNeedsDisplay];
        [cell setNeedsLayout];
    }];
}

// Override to customize the look of a cell representing an object. The default is to display
// a UITableViewCellStyleDefault style cell with the label being the first key in the object.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath object:(PFObject *)object {
    
    NSLog(@"Cell for row: %ld object: %@", (long)[indexPath row], object.objectId);
    
    NSString *CellIdentifier = object.objectId;
    CustomPFTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[CustomPFTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    
        // Configure the cell
        
        NSUInteger numberOfMessagesCached = [[NSUserDefaults standardUserDefaults] objectForKey:object.objectId]? [[NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:object.objectId]] count]: 0;
        NSLog(@"numberOfMessagesCached: %lu", (unsigned long)numberOfMessagesCached);
        NSUInteger totalNumberofMessages = [object[@"messageCount"] unsignedIntegerValue];
        NSLog(@"totalNumberofMessages: %lu", (unsigned long)totalNumberofMessages);
        if (totalNumberofMessages > numberOfMessagesCached) {
            [cell setBadgeText:[NSString stringWithFormat:@"%lu", totalNumberofMessages - numberOfMessagesCached]];
        }

        cell.backgroundColor = [UIColor clearColor];
        
         PFObject *otherUser = [object[@"participants"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.objectId != %@", [PFUser currentUser].objectId]].firstObject;
        
        // TODO: doesnt work with caching
        
//        NSLog(@"%@", [PFUser currentUser]);
//        NSLog(@"%@", otherUser);
        NSLog(@"Fetching %@...", otherUser.objectId);

        cell.imageView.image = [UIImage imageNamed:@"big_screen_bg_BLUR"];
        
        if ([self.cachedUsers objectForKey:otherUser.objectId]) {
            NSLog(@"%@ cached", otherUser.objectId);
            [self configureCellAsync:cell user:(PFUser *)self.cachedUsers[otherUser.objectId] index:[indexPath row]];
        } else {
            [otherUser fetchIfNeededInBackgroundWithBlock:^(PFObject *object, NSError *error) {
                [self configureCellAsync:cell user:(PFUser *)otherUser index:[indexPath row]];
            }];
        }
        
        CGFloat toValue = CGRectGetMidX(self.view.bounds);

        POPSpringAnimation *onscreenAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerPositionX];
        onscreenAnimation.fromValue = @(-toValue);
        onscreenAnimation.toValue = @(toValue);
        onscreenAnimation.springBounciness = 5.0f;
        onscreenAnimation.beginTime = (CACurrentMediaTime() + delay);
        onscreenAnimation.delegate = self;
        onscreenAnimation.name = [NSString stringWithFormat:@"%ld", (long)[indexPath row]];
        delay+=0.7;

        cell.hidden = YES;

        [cell.layer pop_addAnimation:onscreenAnimation forKey:onscreenAnimation.name];
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    CustomPFTableViewCell *cell = (CustomPFTableViewCell*)[tableView cellForRowAtIndexPath:indexPath];
    [cell resetBadge];
    self.recipient = cell.user;
    [self performSegueWithIdentifier:@"seguePushChat" sender:self];
}

/*
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:<#@"reuseIdentifier"#> forIndexPath:indexPath];
    
    // Configure the cell...
    
    return cell;
}
*/

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    
    if ([segue.identifier isEqualToString:@"seguePushChat"]) {
        UINavigationController *nc = segue.destinationViewController;
        ChatViewController *vc = (ChatViewController *)nc.topViewController;
        vc.recipient = self.recipient;
        vc.delegateModal = self;
        
    }

    if ([segue.identifier isEqualToString:@"showDestinationsFromList"]) {
        UINavigationController *navigationViewController = segue.destinationViewController;
        DestinationViewController *destinationViewController = (DestinationViewController*)navigationViewController.topViewController;
        destinationViewController.incoming = YES;
    }
}

- (IBAction)showUnreadRequests:(id)sender {
    [self performSegueWithIdentifier:@"showDestinationsFromList" sender:self];
}

//- (IBAction)addConversation:(id)sender {
//    
//    NSLog(@"Creating a new conversation...");
//    
//    PFObject *conversation = [PFObject objectWithClassName:@"Conversation"];
//    PFQuery *query = [PFUser query];
//    PFUser *suser = (PFUser*)[query getObjectWithId:@"gA6OFGSMZz"];
//    conversation[@"participants"] = [NSArray arrayWithObjects:[PFUser currentUser], suser, nil];
//    [conversation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
//        Message *message = [[Message alloc] initw initWithText:@"test" recipient:suser conversation:conversation];
//        [message saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
//        }];
//    }];
//}

- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
//    if (motion == UIEventSubtypeMotionShake) {
//        NSLog(@"Device started shaking!");
//        
//        CAKeyframeAnimation * anim = [ CAKeyframeAnimation animationWithKeyPath:@"transform" ] ;
//        anim.values = @[ [ NSValue valueWithCATransform3D:CATransform3DMakeTranslation(-5.0f, 0.0f, 0.0f) ], [ NSValue valueWithCATransform3D:CATransform3DMakeTranslation(5.0f, 0.0f, 0.0f) ] ] ;
//        anim.autoreverses = YES ;
//        anim.repeatCount = 2.0f ;
//        anim.duration = 0.07f ;
//        
//        [self.view.layer addAnimation:anim forKey:nil];
//        
//        [[NSNotificationCenter defaultCenter] postNotificationName:@"shakeNotification" object:nil];
//
//    }
}

@end
