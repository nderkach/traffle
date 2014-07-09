//
//  Created by Jesse Squires
//  http://www.hexedbits.com
//
//
//  Documentation
//  http://cocoadocs.org/docsets/JSQMessagesViewController
//
//
//  GitHub
//  https://github.com/jessesquires/JSQMessagesViewController
//
//
//  License
//  Copyright (c) 2014 Jesse Squires
//  Released under an MIT license: http://opensource.org/licenses/MIT
//

#import <Parse/Parse.h>
#import <JSQMessagesViewController.h>
#import <JSQMessageData.h>

@class ChatViewController;

@protocol ChatViewControllerDelegate <NSObject>

- (void)didDismissChatViewController:(ChatViewController *)vc;

@end

@interface Message : PFObject <JSQMessageData>

- (NSDate *)date;
- (NSString *)sender;
- (NSString *)text;
- (id)initWithText:(NSString *)text sender:(PFUser *)sender recipient:(PFUser *)recipient conversation:(PFObject *)conversation;

@end

@interface ChatViewController : JSQMessagesViewController <JSQMessagesCollectionViewDataSource, JSQMessagesCollectionViewDelegateFlowLayout>

@property (strong, nonatomic) id<ChatViewControllerDelegate> delegateModal;

@property (strong, nonatomic) NSMutableArray *messages;
@property (copy, nonatomic) NSDictionary *avatars;

@property (strong, nonatomic) UIImageView *outgoingBubbleImageView;
@property (strong, nonatomic) UIImageView *incomingBubbleImageView;

@property (nonatomic, strong) PFObject *conversation;
@property (nonatomic, strong) PFUser *recipient;

- (void)receiveMessagePressed:(UIBarButtonItem *)sender;

- (void)closePressed:(UIBarButtonItem *)sender;

//- (void)setupTestModel;

@end
