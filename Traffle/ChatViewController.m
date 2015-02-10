//
//  ChatViewController.h
//  Traffle
//
//  Created by Nikolay Derkach on 28/05/14.
//  Copyright (c) 2014 Nikolay Derkach. All rights reserved.
//

#import <JSQMessages.h>
#import <JSQMessage.h>
#import <MBProgressHUD.h>
#import <Crashlytics/Crashlytics.h>
#import <UIImage+Resize.h>

#import "ChatViewController.h"
#import "Constants.h"
#import "camera.h"

@interface ChatViewController ()
{
    NSTimer *timer;
    BOOL isLoading;
    
    NSMutableArray *users;
    NSMutableArray *messages;
    NSMutableDictionary *avatars;
    
    JSQMessagesBubbleImage *bubbleImageOutgoing;
    JSQMessagesBubbleImage *bubbleImageIncoming;
    JSQMessagesAvatarImage *avatarImageBlank;
}

@property (strong, nonatomic) NSMutableArray *messageObjects;
@property (strong, nonatomic) MBProgressHUD *progressHud;
@property (strong, nonatomic) PFUser *recipient;
@property (strong, nonatomic) UIImageView *outgoingBubbleImageView;
@property (strong, nonatomic) UIImageView *incomingBubbleImageView;

@end

@implementation ChatViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (isiPhone5orHigher) {
        self.collectionView.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"big_screen_bg_BLUR"]];
    } else {
        // iPhone 4/4S support
        self.collectionView.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"small_screen_bg_BLUR"]];
    }
    
    users = [[NSMutableArray alloc] init];
    messages = [[NSMutableArray alloc] init];
    avatars = [[NSMutableDictionary alloc] init];
    
    // initilize JSQMessagesViewController parameters
    PFUser *user = [PFUser currentUser];
    self.senderId = user.objectId;
    self.senderDisplayName = user[@"Name"];
    
    self.collectionView.collectionViewLayout.messageBubbleFont = [UIFont systemFontOfSize:15.0f];
    self.recipient = [self.conversation[@"participants"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.objectId != %@", [PFUser currentUser].objectId]].firstObject;
    [self.recipient fetchIfNeededInBackgroundWithBlock:^(PFObject *object, NSError *error) {
        self.title = self.recipient[@"Name"];
    }];
    
    avatarImageBlank = [JSQMessagesAvatarImageFactory avatarImageWithImage:[UIImage imageNamed:@"chat_blank"] diameter:30.0];

    JSQMessagesBubbleImageFactory *bubbleFactory = [[JSQMessagesBubbleImageFactory alloc] init];
    bubbleImageOutgoing = [bubbleFactory
                                    outgoingMessagesBubbleImageWithColor:kTraffleMainColor];
    bubbleImageIncoming = [bubbleFactory
                                    incomingMessagesBubbleImageWithColor:[UIColor whiteColor]];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.collectionView.collectionViewLayout.springinessEnabled = YES;
    // refresh chat messages periodically
    timer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(loadMessages) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[self navigationController] setNavigationBarHidden:YES animated:YES];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [timer invalidate];

    [super viewWillDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.progressHud = [MBProgressHUD showHUDAddedTo:self.collectionView animated:YES];
    [self.progressHud setLabelText:@"Loading..."];
    [self.progressHud setDimBackground:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(broughtToForeground) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    
    [[self navigationController] setNavigationBarHidden:NO animated:YES];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                                                          target:self
                                                                                          action:@selector(closePressed:)];
    
    self.navigationItem.leftBarButtonItem.tintColor = kTraffleMainColor;
    
    isLoading = NO;
    [self loadMessages];
}

#pragma mark - Backend methods

- (void)loadMessages
{
    if (isLoading == NO)
    {
        isLoading = YES;
        JSQMessage *message_last = [messages lastObject];
        
        /* Check if there is an already existing conversation between users */
        
        PFQuery *query = [PFQuery queryWithClassName:@"Message"];
        [query whereKey:@"conversation" equalTo:self.conversation];
        if (message_last != nil) [query whereKey:@"createdAt" greaterThan:message_last.date];
        [query includeKey:@"sender"];
        [query includeKey:@"recipient"];
        [query orderByDescending:@"createdAt"];
        [query setLimit:50];
        [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
         {
             if (error == nil)
             {
                 bool receivedAny = NO;
                 self.automaticallyScrollsToMostRecentMessage = NO;
                 for (id msg in [objects reverseObjectEnumerator])
                 {
                     PFUser *sender = ((PFObject*)msg)[@"sender"];
                     PFUser *currentUser = [PFUser currentUser];
                     if (![sender.objectId isEqualToString:currentUser.objectId]) {
                         receivedAny = YES;
                     }
                     [self addMessage:msg];
                 }
                 if ([objects count] != 0)
                 {
                     [self finishReceivingMessage];
                     [self scrollToBottomAnimated:NO];
                     if (receivedAny) {
                         [JSQSystemSoundPlayer jsq_playMessageReceivedSound];
                     }
                 }
                 self.automaticallyScrollsToMostRecentMessage = YES;
                 
                 // messages are read now
                 PFQuery *query = [PFQuery queryWithClassName:@"Unread"];
                 [query whereKey:@"conversation" equalTo:self.conversation];
                 [query whereKey:@"user" equalTo:[PFUser currentUser]];
                 [query getFirstObjectInBackgroundWithBlock:^(PFObject *object, NSError *error) {
                     
                     PFInstallation *currentInstallation = [PFInstallation currentInstallation];
                     if (currentInstallation.badge > [object[@"count"] intValue]) {
                         currentInstallation.badge -= [object[@"count"] intValue];
                     } else {
                         currentInstallation.badge = 0;
                     }
                     [currentInstallation saveInBackground];
                     
                     object[@"count"] = @0;
                     [object saveInBackground];
                 }];
             }
             isLoading = NO;
             [self.progressHud hide:YES];
         }];
    }
}

- (void)addMessage:(PFObject *)object
{
    PFUser *user = object[@"sender"];
    [users addObject:user];

    if (object[@"picture"] == nil)
    {
        JSQMessage *message = [[JSQMessage alloc] initWithSenderId:user.objectId senderDisplayName:user[@"Name"]
                                                              date:object.createdAt text:object[@"text"]];
        [messages addObject:message];
        [self.collectionView reloadData];
    }

    if (object[@"picture"] != nil)
    {
        JSQPhotoMediaItem *mediaItem = [[JSQPhotoMediaItem alloc] initWithImage:nil];
        mediaItem.appliesMediaViewMaskAsOutgoing = [user.objectId isEqualToString:[PFUser currentUser].objectId];
        JSQMessage *message = [[JSQMessage alloc] initWithSenderId:user.objectId senderDisplayName:user[@"Name"] date:object.createdAt media:mediaItem];
        [messages addObject:message];

        PFFile *filePicture = object[@"picture"];
        [filePicture getDataInBackgroundWithBlock:^(NSData *imageData, NSError *error) {
            if (error == nil) {
                mediaItem.image = [UIImage imageWithData:imageData];
                [self.collectionView reloadData];
            }
        }];
    }
}

- (void)sendMessage:(NSString *)text Picture:(UIImage *)picture
{
    PFFile *filePicture = nil;
    if (picture != nil)
    {
        filePicture = [PFFile fileWithName:@"picture.jpg" data:UIImageJPEGRepresentation(picture, 0.6)];
        [filePicture saveInBackground];
    }
    
    PFObject *object = [PFObject objectWithClassName:@"Message"];
    object[@"sender"] = [PFUser currentUser];
    object[@"recipient"] = self.recipient;
    object[@"text"] = text;
    object[@"conversation"] = self.conversation;
    if (filePicture != nil) object[@"picture"] = filePicture;
    [object saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error)
     {
         if (error == nil)
         {
             [JSQSystemSoundPlayer jsq_playMessageSentSound];
             [self loadMessages];
             
             PFQuery * query = [PFQuery queryWithClassName:@"Unread"];
             [query whereKey:@"user" equalTo:self.recipient];
             [query whereKey:@"conversation" equalTo:self.conversation];
             [query getFirstObjectInBackgroundWithBlock:^(PFObject *object, NSError *error) {
                 if (!error) {
                     [object incrementKey:@"count"];
                     [object saveInBackground];
                 } else {
                     PFObject *new = [PFObject objectWithClassName:@"Unread"];
                     new[@"conversation"] = self.conversation;
                     new[@"user"] = self.recipient;
                     new[@"count"] = @1;
                     [new saveInBackground];
                 }
             }];
         }
     }];
    
    [self sendPushNotification:text];
    [self finishSendingMessage];
}

#pragma mark - JSQMessagesViewController method overrides

- (void)didPressSendButton:(UIButton *)button withMessageText:(NSString *)text senderId:(NSString *)senderId senderDisplayName:(NSString *)senderDisplayName date:(NSDate *)date
{
    [self sendMessage:text Picture:nil];
}

- (void)didPressAccessoryButton:(UIButton *)sender
{
    UIActionSheet *action = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil
                                               otherButtonTitles:@"Take photo", @"Choose existing photo", nil];
    [action showInView:self.view];
}

#pragma mark - JSQMessages CollectionView DataSource

- (id<JSQMessageData>)collectionView:(JSQMessagesCollectionView *)collectionView messageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [messages objectAtIndex:indexPath.item];
}

- (id<JSQMessageBubbleImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView
             messageBubbleImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    JSQMessage *message = messages[indexPath.item];
    
    if ([message.senderId isEqualToString:[PFUser currentUser].objectId])
    {
        return bubbleImageOutgoing;
    }
    return bubbleImageIncoming;
}

- (id<JSQMessageAvatarImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView
                    avatarImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    PFUser *user = users[indexPath.item];
    if (avatars[user.objectId] == nil)
    {
        PFFile *fileThumbnail = user[@"Photo"];
        [fileThumbnail getDataInBackgroundWithBlock:^(NSData *imageData, NSError *error)
         {
             if (error == nil)
             {
                 avatars[user.objectId] = [JSQMessagesAvatarImageFactory avatarImageWithImage:[UIImage imageWithData:imageData] diameter:30.0];
                 [self.collectionView reloadData];
             }
         }];
        return avatarImageBlank;
    }
    else return avatars[user.objectId];
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.item % 3 == 0) {
        JSQMessage *message = [messages objectAtIndex:indexPath.item];
        NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        paragraphStyle.alignment = NSTextAlignmentCenter;
        NSDictionary *dateAttrs = @{ NSFontAttributeName : [UIFont fontWithName:@"AvenirNextCondensed-DemiBold" size:12.0f],
                                     NSForegroundColorAttributeName : [UIColor whiteColor],
                                     NSParagraphStyleAttributeName : paragraphStyle };
        [[JSQMessagesTimestampFormatter sharedFormatter] setDateTextAttributes:dateAttrs];
        
        NSDictionary *timeAttrs = @{ NSFontAttributeName : [UIFont fontWithName:@"AvenirNextCondensed-Regular" size:12.0f],
                                     NSForegroundColorAttributeName : [UIColor whiteColor],
                                     NSParagraphStyleAttributeName : paragraphStyle };
        [[JSQMessagesTimestampFormatter sharedFormatter] setTimeTextAttributes:timeAttrs];
        return [[JSQMessagesTimestampFormatter sharedFormatter] attributedTimestampForDate:message.date];
    }
    
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

#pragma mark - UICollectionView DataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [messages count];
}

- (UICollectionViewCell *)collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    JSQMessagesCollectionViewCell *cell = (JSQMessagesCollectionViewCell *)[super collectionView:collectionView cellForItemAtIndexPath:indexPath];
    
    JSQMessage *msg = [messages objectAtIndex:indexPath.item];
    
    if ([msg.senderId isEqualToString:[PFUser currentUser].objectId]) {
        cell.textView.textColor = [UIColor whiteColor];
        cell.textView.linkTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor], NSUnderlineStyleAttributeName: [NSNumber numberWithInt:NSUnderlineStyleSingle]};
    }
    else {
        cell.textView.textColor = [UIColor blackColor];
        cell.textView.linkTextAttributes = @{NSForegroundColorAttributeName: [UIColor blackColor], NSUnderlineStyleAttributeName: [NSNumber numberWithInt:NSUnderlineStyleSingle]};
    }
    
    return cell;
}

#pragma mark - JSQMessages collection view flow layout delegate

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.item % 3 == 0) {
        return kJSQMessagesCollectionViewCellLabelHeightDefault;
    }
    
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    JSQMessage *message = messages[indexPath.item];
    if ([message.senderId isEqualToString:[PFUser currentUser].objectId])
    {
        return 0;
    }
    
    if (indexPath.item - 1 > 0)
    {
        JSQMessage *previousMessage = messages[indexPath.item-1];
        if ([previousMessage.senderId isEqualToString:message.senderId])
        {
            return 0;
        }
    }
    return kJSQMessagesCollectionViewCellLabelHeightDefault;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

#pragma mark - Responding to collection view tap events

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
                header:(JSQMessagesLoadEarlierHeaderView *)headerView didTapLoadEarlierMessagesButton:(UIButton *)sender
{
    NSLog(@"didTapLoadEarlierMessagesButton");
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapAvatarImageView:(UIImageView *)avatarImageView
           atIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"didTapAvatarImageView");
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapMessageBubbleAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"didTapMessageBubbleAtIndexPath");
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapCellAtIndexPath:(NSIndexPath *)indexPath touchLocation:(CGPoint)touchLocation
{
    NSLog(@"didTapCellAtIndexPath %@", NSStringFromCGPoint(touchLocation));
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != actionSheet.cancelButtonIndex)
    {
        if (buttonIndex == 0)	ShouldStartCamera(self, YES);
        if (buttonIndex == 1)	ShouldStartPhotoLibrary(self, YES);
    }
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *picture = info[UIImagePickerControllerEditedImage];
    [self sendMessage:@"[Picture message]" Picture:picture];
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Push notifications

- (void)sendPushNotification:(NSString *)text
{
    PFQuery *queryInstallation = [PFInstallation query];
    [queryInstallation whereKey:@"installationUser" equalTo:self.recipient.objectId];
    
    NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSString stringWithFormat:@"New message from %@", [PFUser currentUser][@"Name"]], @"alert",
                          @"Increment", @"badge",
                          @"message", @"type",
                          @1, @"content-available",
                          [NSString stringWithFormat:@"%@", [PFUser currentUser].objectId], @"from",
                          [NSString stringWithFormat:@"%@", self.conversation.objectId], @"conversation",
                          text, @"text",
                          nil];
    
    PFPush *push = [[PFPush alloc] init];
    [push setQuery:queryInstallation];
    [push setMessage:text];
    [push setData:data];
    [push sendPushInBackgroundWithBlock:^(BOOL succeeded, NSError *error)
     {
         if (error != nil)
         {
             NSLog(@"SendPushNotification send error.");
         }
     }];
}

- (void)closePressed:(UIBarButtonItem *)sender
{
    if (self.delegateModal) {
        [self.delegateModal didDismissChatViewController:self];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
}

#pragma mark - Misc

- (void) broughtToForeground
{
    [self finishReceivingMessage];
}

@end