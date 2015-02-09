//
//  ListTableViewController.m
//  Traffle
//
//  Created by Nikolay Derkach on 28/05/14.
//  Copyright (c) 2014 Nikolay Derkach. All rights reserved.
//

#import <POP.h>
#import <Crashlytics/Crashlytics.h>
#import <Parse/Parse.h>
#import <MBProgressHUD/MBProgressHUD.h>

#import "ListTableViewController.h"
#import "ChatViewController.h"
#import "DestinationViewController.h"
#import "Constants.h"
#import "CustomTableViewCell.h"

static int delay = 0.0;

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

@interface ListTableViewController ()
{
    NSMutableArray *conversations;
    UIRefreshControl *refreshControl;
}

@property (strong, nonatomic) NSMutableArray *users;
@property (strong, nonatomic) MBProgressHUD *progressHud;
@property (strong, nonatomic) NSMutableDictionary *unreadCounts;
@property (strong, nonatomic) NSArray *incomingRequests;

@end

@implementation ListTableViewController

- (void)didDismissChatViewController:(ChatViewController *)vc
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.unreadCounts = [[NSMutableDictionary alloc] init];
    
    if (isiPhone5) {
        self.tableConversations.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"big_screen_bg_BLUR"]];
    } else {
        self.tableConversations.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"small_screen_bg_BLUR"]];
    }

    self.tableConversations.tableFooterView = [[UIView alloc] init];
    
    self.tableConversations.separatorColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"separator"]];
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];

    refreshControl = [[UIRefreshControl alloc] init];
    refreshControl.tintColor = [UIColor whiteColor];
    [refreshControl addTarget:self action:@selector(loadMessages) forControlEvents:UIControlEventValueChanged];
    [self.tableConversations addSubview:refreshControl];

    conversations = [[NSMutableArray alloc] init];
    
    if ([PFUser currentUser] != nil)
    {
        [self loadMessagesWithHud];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
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

- (void)loadMessagesWithHud
{
    self.progressHud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [self.progressHud setLabelText:@"Loading..."];
    [self.progressHud setDimBackground:YES];
    [self loadMessages];
}

- (void)loadMessages
{
    if ([PFUser currentUser] != nil)
    {
        PFQuery *query = [PFQuery queryWithClassName:@"Conversation"];
        [query whereKey:@"participants" equalTo:[PFUser currentUser]];
        [query includeKey:@"participants"];
        [query orderByDescending:@"updatedAt"];
        [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
         {
             if (error == nil)
             {
                 // get unread messages counts
                 __block NSArray* fetchedConversations = objects;
                 PFQuery *query = [PFQuery queryWithClassName:@"Unread"];
                 [query whereKey:@"user" equalTo:[PFUser currentUser]];
                 [query whereKey:@"conversation" containedIn:objects];
                 [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
                     for (PFObject *object in objects) {
                         self.unreadCounts[((PFObject*)object[@"conversation"]).objectId] = object[@"count"];
                     }
                     
                     [conversations removeAllObjects];
                     [conversations addObjectsFromArray:fetchedConversations];
                     [self.tableConversations reloadData];
                 }];

             }
//             else [ProgressHUD showError:@"Network error."];
             [refreshControl endRefreshing];
             [self.progressHud hide:YES];
         }];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    PFQuery *query = [PFQuery queryWithClassName:@"Request"];
    [query whereKey:@"accepted" equalTo:[NSNull null]];
    [query whereKey:@"toUser" equalTo:[PFUser currentUser]];
    [query includeKey:@"fromUser"];
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
            self.incomingRequests = objects;
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

-(void)pop_animationDidStart:(POPAnimation *)anim
{
    UITableViewCell *cell = [self.tableConversations cellForRowAtIndexPath: [NSIndexPath indexPathForRow:[anim.name intValue] inSection:0]];
    cell.hidden = NO;
}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [conversations count];
}

//- (void)configureCellAsync:(CustomPFTableViewCell *)cell user:(PFUser *)user index:(NSUInteger)index
//{
//    CLS_LOG(@"configureCellAsync %@ at index %lu...", user, (unsigned long)index);
//    
//    cell.user = user;
//    
//    PFFile *thumbnail = user[@"Photo"];
//    
//    UIFont *avenirFont = [UIFont fontWithName:@"AvenirNextCondensed-Regular" size:21.0f];
//    UIFont *avenirFontDemiBold = [UIFont fontWithName:@"AvenirNextCondensed-DemiBold" size:21.0f];
//    NSDictionary *avenirFontDict = [NSDictionary dictionaryWithObject:avenirFont forKey:NSFontAttributeName];
//    NSDictionary *avenirFontDemiBoldDict = [NSDictionary dictionaryWithObject:avenirFontDemiBold forKey:NSFontAttributeName];
//    NSMutableAttributedString *finalString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@, ", user[@"Name"]] attributes: avenirFontDict];
//   
//    NSMutableAttributedString *cityString;
//    if (user[@"city"]) {
//        cityString = [[NSMutableAttributedString alloc] initWithString:user[@"city"] attributes: avenirFontDemiBoldDict];
//    } else {
//        cityString = [[NSMutableAttributedString alloc] initWithString:@"Mars" attributes: avenirFontDemiBoldDict];
//    }
//    
//    [finalString appendAttributedString:cityString];
//    
//    cell.textLabel.attributedText = finalString;
//    cell.textLabel.textColor = [UIColor whiteColor];
//    
//    [thumbnail getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
//        [cell.imageView setImage:[UIImage imageWithData:data]];
//        [cell.imageView setNeedsDisplay];
//        [cell setNeedsLayout];
//    }];
//}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PFObject *conversation = (PFObject*)(conversations[indexPath.row]);
    NSString *cellIdentifier = conversation.objectId;
    CustomTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        NSLog(@"New cell");
        cell = [[CustomTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        [cell bindData:conversations[indexPath.row]];
        if ([self.unreadCounts[conversation.objectId] integerValue] > 0) {
            [cell setBadgeText:[NSString stringWithFormat:@"%@", self.unreadCounts[conversation.objectId]]];
        }
    }
    
//    CustomTableViewCell *cell = [[CustomTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
//    [cell bindData:conversations[indexPath.row]];

    
    // set badge
    
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
    
    return cell;
}

//- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath object:(PFObject *)object {
//    
//
//        if ([self.cachedUsers objectForKey:otherUser.objectId]) {
//            NSLog(@"%@ cached", otherUser.objectId);
//            [self configureCellAsync:cell user:(PFUser *)self.cachedUsers[otherUser.objectId] index:[indexPath row]];
//        } else {
//            [otherUser fetchIfNeededInBackgroundWithBlock:^(PFObject *object, NSError *error) {
//                [self configureCellAsync:cell user:(PFUser *)otherUser index:[indexPath row]];
//            }];
//        }
//
//    }
//
//    return cell;
//}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    CustomTableViewCell *cell = (CustomTableViewCell*)[tableView cellForRowAtIndexPath:indexPath];
//    [cell resetBadge];
    self.selectedConversation = cell.conversation;
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
        vc.conversation = self.selectedConversation;
        vc.delegateModal = self;
    }

    if ([segue.identifier isEqualToString:@"showDestinationsFromList"]) {
        UINavigationController *navigationViewController = segue.destinationViewController;
        DestinationViewController *destinationViewController = (DestinationViewController*)navigationViewController.topViewController;
        destinationViewController.incoming = YES;
        destinationViewController.requests = [[NSMutableArray alloc] initWithArray:self.incomingRequests];
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

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [conversations[indexPath.row] deleteInBackgroundWithBlock:^(BOOL succeeded, NSError *error)
     {
         if (error != nil) NSLog(@"DeleteMessageItem delete error.");
     }];
    [conversations removeObjectAtIndex:indexPath.row];
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
}



@end
