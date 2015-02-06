//
//  ListTableViewController.h
//  Traffle
//
//  Created by Nikolay Derkach on 28/05/14.
//  Copyright (c) 2014 Nikolay Derkach. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Parse/Parse.h>

#import "ChatViewController.h"

@interface ListTableViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, ChatViewControllerDelegate>

@property (nonatomic, strong) PFObject *selectedConversation;
@property (strong, nonatomic) IBOutlet UIButton *showUnreadRequestsButton;
//@property (nonatomic, strong) NSDictionary *cachedUsers;
@property (strong, nonatomic) IBOutlet UITableView *tableConversations;

- (IBAction)showUnreadRequests:(id)sender;

@end
