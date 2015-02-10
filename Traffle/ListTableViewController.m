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

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new]
                                                  forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [UIImage new];
    self.navigationController.navigationBar.translucent = YES;
    self.navigationController.view.backgroundColor = [UIColor clearColor];
    
    self.unreadCounts = [[NSMutableDictionary alloc] init];
    
    if (isiPhone5orHigher) {
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


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
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

#pragma messages

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

                     [refreshControl endRefreshing];
                     [self.progressHud hide:YES];
                 }];

             }
         }];
    }
}

# pragma mark UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [conversations count];
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 100.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PFObject *conversation = (PFObject*)(conversations[indexPath.row]);
    NSString *cellIdentifier = conversation.objectId;
    CustomTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[CustomTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        [cell bindData:conversations[indexPath.row]];
        if ([self.unreadCounts[conversation.objectId] integerValue] > 0) {
            [cell setBadgeText:[NSString stringWithFormat:@"%@", self.unreadCounts[conversation.objectId]]];
        }
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
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    CustomTableViewCell *cell = (CustomTableViewCell*)[tableView cellForRowAtIndexPath:indexPath];
    self.selectedConversation = cell.conversation;
    [self performSegueWithIdentifier:@"seguePushChat" sender:self];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [conversations[indexPath.row] deleteInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (error != nil) NSLog(@"DeleteMessageItem delete error.");
    }];
    [conversations removeObjectAtIndex:indexPath.row];
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
}

#pragma animations

-(void)pop_animationDidStart:(POPAnimation *)anim
{
    UITableViewCell *cell = [self.tableConversations cellForRowAtIndexPath: [NSIndexPath indexPathForRow:[anim.name intValue] inSection:0]];
    cell.hidden = NO;
}

#pragma mark Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
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

#pragma mark misc

- (void)didDismissChatViewController:(ChatViewController *)vc
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end