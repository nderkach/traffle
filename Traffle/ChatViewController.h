//
//  ChatViewController.h
//  Traffle
//
//  Created by Nikolay Derkach on 28/05/14.
//  Copyright (c) 2014 Nikolay Derkach. All rights reserved.
//

#import <Parse/Parse.h>
#import <JSQMessagesViewController.h>
#import <JSQMessageData.h>

@class ChatViewController;

@protocol ChatViewControllerDelegate <NSObject>

- (void)didDismissChatViewController:(ChatViewController *)vc;

@end

@interface ChatViewController : JSQMessagesViewController <JSQMessagesCollectionViewDataSource, JSQMessagesCollectionViewDelegateFlowLayout, UIImagePickerControllerDelegate, UIActionSheetDelegate>

@property (strong, nonatomic) id<ChatViewControllerDelegate> delegateModal;
@property (strong, nonatomic) PFObject *conversation;

- (void)closePressed:(UIBarButtonItem *)sender;

@end
