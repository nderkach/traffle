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

#import <JSQMessages.h>
#import <JSQMessage.h>
#import <MBProgressHUD.h>
#import <Crashlytics/Crashlytics.h>
#import <UIImage+Resize.h>

#import "ChatViewController.h"
#import "Constants.h"
#import "camera.h"

@interface Message ()

@end

@implementation Message

- (NSDate *)date
{
    return self.createdAt;
}

- (NSString *)sender
{
    return ((PFUser *)[self objectForKey:@"sender"]).username;
}

- (NSString *)text
{
    return [self objectForKey:@"text"];
}

//- (PFObject *)conversation
//{
//    return self[@"conversation"] ;
//}
//
//- (PFObject *)senderObject
//{
//    return self[@"sender"];
//}
//
//- (PFObject *)recipient
//{
//    return self[@"recipient"];
//}


- (id)initWithText:(NSString *)text sender:(PFUser *)sender recipient:(PFUser *)recipient conversation:(PFObject *)conversation
{
    if (self = [super initWithClassName:@"Message"]) {
        // initializer logic
        
        CLS_LOG("Init message with: %@, %@, %@, %@", sender, recipient, conversation, text);
        self[@"conversation"] = conversation;
        self[@"sender"] = sender;
        self[@"recipient"] = recipient;
        self[@"text"] = text;
    }
    return self;
}

//- (instancetype)initWithCoder:(NSCoder *)aDecoder
//{
//    self = [super init];
//    if (self) {
//        self[@"date"] = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(date))];
//        self[@"sender"] = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(sender))];
//        self[@"text"] = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(text))];
//    }
//    return self;
//}
//
//- (void)encodeWithCoder:(NSCoder *)aCoder
//{
//    [aCoder encodeObject:self.date forKey:NSStringFromSelector(@selector(date))];
//    [aCoder encodeObject:self.sender forKey:NSStringFromSelector(@selector(sender))];
//    [aCoder encodeObject:self.text forKey:NSStringFromSelector(@selector(text))];
//}

@end

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

@end

@implementation ChatViewController

- (UIImage *)blendImagesWithBackground: (UIImage *)background foreground: (UIImage *)foreground
{
    UIImageView* imageView = [[UIImageView alloc] initWithImage:background];
    UIImage *resizedForeground = [foreground resizedImage:CGSizeMake(background.size.width-8.0f, background.size.height-8.0f) interpolationQuality:kCGInterpolationDefault];
    UIImageView* subView = [[UIImageView alloc] initWithImage:resizedForeground];
    subView.frame = CGRectInset(imageView.frame, 4.0f, 4.0f);
    subView.layer.cornerRadius = resizedForeground.size.width/2.0f;
    subView.layer.masksToBounds = YES;
    [imageView addSubview:subView];
    UIGraphicsBeginImageContext(imageView.frame.size);
    [imageView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage* blendedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return blendedImage;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (isiPhone5) {
        self.collectionView.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"big_screen_bg_BLUR"]];
    } else {
        self.collectionView.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"small_screen_bg_BLUR"]];
    }
    
    users = [[NSMutableArray alloc] init];
    messages = [[NSMutableArray alloc] init];
    avatars = [[NSMutableDictionary alloc] init];
    
    UIFont *avenirFont = [UIFont fontWithName:@"AvenirNextCondensed-Regular" size:20.5f];
    self.collectionView.collectionViewLayout.messageBubbleFont = avenirFont;
    self.recipient = [self.conversation[@"participants"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.objectId != %@", [PFUser currentUser].objectId]].firstObject;
    self.title = self.recipient[@"Name"];
//    self.sender = [PFUser currentUser].username;
    
//    self.avatars = [[NSMutableDictionary alloc] init];
    
//    CGFloat outgoingDiameter = self.collectionView.collectionViewLayout.outgoingAvatarViewSize.width;
    
//    PFFile *file = [PFUser currentUser][@"Photo"];
//
//    NSLog(@"Getting current user photo...");
//    
//    [file getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
//        if (!error) {
//            
//            UIImage *img = [UIImage imageWithData:data];
//            
//            NSLog(@"image.size.width: %f, image.size.height: %f", img.size.width, img.size.height);
//            NSLog(@"%f", outgoingDiameter);
//            
////            UIImage *senderAvatar = [self blendImagesWithBackground:[UIImage imageNamed:@"ci_profile_mask_alpha"] foreground:[UIImage imageWithData:data]];
//            
////            UIImage *senderAvatar = [UIImage imageNamed:@"ci_profile_mask_alpha"];
//            
//            UIImage *senderAvatar = [UIImage imageWithData:data];
//            
//            UIImage *senderImage = [JSQMessagesAvatarFactory avatarWithImage:senderAvatar
//                                                                diameter:outgoingDiameter];
//            
//            NSLog(@"image.size.width: %f, image.size.height: %f", senderImage.size.width, senderImage.size.height);
//            
//            NSLog(@"Getting current user photo... done");
//
//            [self.recipient fetchIfNeeded];
//            
//            PFFile *file = self.recipient[@"Photo"];
//            
//            NSLog(@"Getting matched user photo...");
//            
//            [file getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
//                if (!error) {
//                    
//                    NSLog(@"Getting matched user photo... done");
//            
//                    UIImage *recipientImage = [JSQMessagesAvatarFactory avatarWithImage:[UIImage imageWithData:data]
//                                                                       diameter:outgoingDiameter];
//                    
//                    
//            
//                    self.avatars = @{ self.sender : senderImage,
//                                      self.recipient.username: recipientImage};
//                    
//                    
//                    
//                }
//            }];
//        }
//    }];
    
    JSQMessagesBubbleImageFactory *bubbleFactory = [[JSQMessagesBubbleImageFactory alloc] init];

    bubbleImageOutgoing = [bubbleFactory
                                    incomingMessagesBubbleImageWithColor:kTraffleMainColor];
    
    bubbleImageIncoming = [bubbleFactory
                                    incomingMessagesBubbleImageWithColor:[UIColor whiteColor]];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.collectionView.collectionViewLayout.springinessEnabled = YES;
    timer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(loadMessages) userInfo:nil repeats:YES];
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
//        [self.collectionView reloadData]; //FIXME
    }

    if (object[@"picture"] != nil)
    {
        JSQPhotoMediaItem *mediaItem = [[JSQPhotoMediaItem alloc] initWithImage:nil];
        mediaItem.appliesMediaViewMaskAsOutgoing = ![user.objectId isEqualToString:[PFUser currentUser].objectId];
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
                 self.automaticallyScrollsToMostRecentMessage = NO;
                 for (PFObject *object in [objects reverseObjectEnumerator])
                 {
                     [self addMessage:object];
                 }
                 if ([objects count] != 0)
                 {
                     [self finishReceivingMessage];
                     [self scrollToBottomAnimated:NO];
                 }
                 self.automaticallyScrollsToMostRecentMessage = YES;
                 
                 // recent unread count
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
                     [currentInstallation saveEventually];
                     
                     object[@"count"] = @0;
                     [object saveEventually];
                 }];
             }
             isLoading = NO;
             [self.progressHud hide:YES];
         }];
    }
}

- (id<JSQMessageBubbleImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView
             messageBubbleImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
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

- (void)sendMessage:(NSString *)text Picture:(UIImage *)picture
{
    PFFile *filePicture = nil;
    if (picture != nil)
    {
        filePicture = [PFFile fileWithName:@"picture.jpg" data:UIImageJPEGRepresentation(picture, 0.6)];
        [filePicture saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error)
         {
//             if (error != nil) [ProgressHUD showError:@"Picture save error."];
         }];
    }

    PFObject *object = [PFObject objectWithClassName:@"Message"];
    object[@"sender"] = [PFUser currentUser];
    object[@"recipient"] = self.recipient;
    object[@"text"] = text;
    object[@"conversation"] = self.conversation;
    NSLog([PFUser currentUser].objectId, self.recipient.objectId, object[@"text"], self.conversation.objectId);
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
                     [object saveEventually];
                 } else {
                     PFObject *new = [PFObject objectWithClassName:@"Unread"];
                     new[@"conversation"] = self.conversation;
                     new[@"user"] = self.recipient;
                     new[@"count"] = @1;
                     [new saveEventually];
                 }
             }];
         }
//         else [ProgressHUD showError:@"Network error."];;
     }];

    [self sendPushNotification:text];

    [self finishSendingMessage];
}

- (void)didPressSendButton:(UIButton *)button withMessageText:(NSString *)text senderId:(NSString *)senderId senderDisplayName:(NSString *)senderDisplayName date:(NSDate *)date
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    [self sendMessage:text Picture:nil];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)didPressAccessoryButton:(UIButton *)sender
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    UIActionSheet *action = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil
                                               otherButtonTitles:@"Take photo", @"Choose existing photo", nil];
    [action showInView:self.view];
}

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

//- (void)didPressSendButton:(UIButton *)button
//           withMessageText:(NSString *)text
//                    sender:(NSString *)sender
//                      date:(NSDate *)date
//{
////    NSLog(@"Text: '%@'", text);
//    /**
//     *  Sending a message. Your implementation of this method should do *at least* the following:
//     *
//     *  1. Play sound (optional)
//     *  2. Add new id<JSQMessageData> object to your data source
//     *  3. Call `finishSendingMessage`
//     */
//    
//    button.enabled = NO;
//    
//    [JSQSystemSoundPlayer jsq_playMessageSentSound];
//    
//    Message *message = [[Message alloc] initWithText:text sender:[PFUser currentUser] recipient:self.recipient conversation:self.conversation];
//    
//    NSLog(@"Saving message");
//    
//    [message saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
//        if (succeeded) {
//            JSQMessage *msg  = [[JSQMessage alloc] initWithText:message.text sender:message.sender date:message.date];
//            [self.messages addObject:msg];
//            
//            [self.conversation incrementKey:@"messageCount"];
//            [self.conversation saveInBackground];
//            
//            NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:
//                                  [NSString stringWithFormat:@"New message from %@", [PFUser currentUser][@"Name"]], @"alert",
//                                  @"Increment", @"badge",
//                                  @"message", @"type",
//                                  @1, @"content-available",
//                                  [NSString stringWithFormat:@"%@", [PFUser currentUser].objectId], @"from",
//                                  text, @"text",
//                                  nil];
//            
//            // Now we’ll need to query all saved installations to find those of our recipients
//            // Create our Installation query using the self.recipients array we already have
//            PFQuery *pushQuery = [PFInstallation query];
//            [pushQuery whereKey:@"installationUser" equalTo:self.recipient.objectId];
//            
//            // Send push notification to our query
//            PFPush *push = [[PFPush alloc] init];
//            [push setQuery:pushQuery];
//            [push setData:data];
//            [push sendPushInBackground];
//            
//            NSLog(@"Added message '%@', %@, %@", message.text, message.sender, message.date);
//            
//            NSData *msgData = [NSKeyedArchiver archivedDataWithRootObject:self.messages];
//            [[NSUserDefaults standardUserDefaults] setObject:msgData forKey:self.conversation.objectId];
//            [[NSUserDefaults standardUserDefaults] synchronize];
//            
//            [self finishSendingMessage];
//            button.enabled = YES;
//            
//        } else {
//            NSLog(@"Error: %@", [error localizedDescription]);
//        }
//    }];
//    
////    JSQMessage *message2 = [[JSQMessage alloc] initWithText:@"test" sender:@"Bob" date:[[NSDate alloc] init]];
////    [self.messages addObject:message2];
//    
////    [self finishSendingMessage];
//    
//    
//}

//- (void)didPressAccessoryButton:(UIButton *)sender
//{
//    NSLog(@"Camera pressed!");
//    /**
//     *  Accessory button has no default functionality, yet.
//     */
//}



#pragma mark - JSQMessages CollectionView DataSource

- (id<JSQMessageData>)collectionView:(JSQMessagesCollectionView *)collectionView messageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [messages objectAtIndex:indexPath.item];
}

//- (UIImageView *)collectionView:(JSQMessagesCollectionView *)collectionView bubbleImageViewForItemAtIndexPath:(NSIndexPath *)indexPath
//{
//    /**
//     *  You may return nil here if you do not want bubbles.
//     *  In this case, you should set the background color of your collection view cell's textView.
//     */
//    
//    /**
//     *  Reuse created bubble images, but create new imageView to add to each cell
//     *  Otherwise, each cell would be referencing the same imageView and bubbles would disappear from cells
//     */
//    
//    NSLog(@"bubble: %ld", (long)indexPath.row);
//    
//    JSQMessage *message = [self.messages objectAtIndex:indexPath.item];
//    
//    
//    
//    if ([message.sender isEqualToString:self.sender]) {
//        return [[UIImageView alloc] initWithImage:self.outgoingBubbleImageView.image
//                                 highlightedImage:self.outgoingBubbleImageView.highlightedImage];
//    }
//    
//    return [[UIImageView alloc] initWithImage:self.incomingBubbleImageView.image
//                             highlightedImage:self.incomingBubbleImageView.highlightedImage];
//}

#pragma mark - UICollectionView DataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [messages count];
}

- (UICollectionViewCell *)collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  Override point for customizing cells
     */
    JSQMessagesCollectionViewCell *cell = (JSQMessagesCollectionViewCell *)[super collectionView:collectionView cellForItemAtIndexPath:indexPath];
    
    /**
     *  Configure almost *anything* on the cell
     *  
     *  Text colors, label text, label colors, etc.
     *
     *
     *  DO NOT set `cell.textView.font` !
     *  Instead, you need to set `self.collectionView.collectionViewLayout.messageBubbleFont` to the font you want in `viewDidLoad`
     *
     *  
     *  DO NOT manipulate cell layout information!
     *  Instead, override the properties you want on `self.collectionView.collectionViewLayout` from `viewDidLoad`
     */
    
    JSQMessage *msg = [messages objectAtIndex:indexPath.item];
    
    if ([msg.senderId isEqualToString:[PFUser currentUser].objectId]) {
        cell.textView.textColor = [UIColor whiteColor];
        cell.textView.linkTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor], NSUnderlineStyleAttributeName: [NSNumber numberWithInt:NSUnderlineStyleSingle]};
    }
    else {
        cell.textView.textColor = [UIColor blackColor];
        cell.textView.linkTextAttributes = @{NSForegroundColorAttributeName: [UIColor blackColor], NSUnderlineStyleAttributeName: [NSNumber numberWithInt:NSUnderlineStyleSingle]};
    }
    
//    cell.textView.linkTextAttributes = @{ NSForegroundColorAttributeName : cell.textView.textColor,
//                                          NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle | NSUnderlinePatternSolid) };
    
    return cell;
}

//- (UIImageView *)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageViewForItemAtIndexPath:(NSIndexPath *)indexPath
//{
//    /**
//     *  Return `nil` here if you do not want avatars.
//     *  If you do return `nil`, be sure to do the following in `viewDidLoad`:
//     *
//     *  self.collectionView.collectionViewLayout.incomingAvatarViewSize = CGSizeZero;
//     *  self.collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSizeZero;
//     *
//     *  It is possible to have only outgoing avatars or only incoming avatars, too.
//     */
//    
//    /**
//     *  Reuse created avatar images, but create new imageView to add to each cell
//     *  Otherwise, each cell would be referencing the same imageView and avatars would disappear from cells
//     *
//     *  Note: these images will be sized according to these values:
//     *
//     *  self.collectionView.collectionViewLayout.incomingAvatarViewSize
//     *  self.collectionView.collectionViewLayout.outgoingAvatarViewSize
//     *
//     *  Override the defaults in `viewDidLoad`
//     */
//    JSQMessage *message = [self.messages objectAtIndex:indexPath.item];
//    
//    UIImage *avatarImage = [self.avatars objectForKey:message.senderId];
//    return [[UIImageView alloc] initWithImage:avatarImage];
//}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  This logic should be consistent with what you return from `heightForCellTopLabelAtIndexPath:`
     *  The other label text delegate methods should follow a similar pattern.
     *
     *  Show a timestamp for every 3rd message
     */
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
//    JSQMessage *message = [self.messages objectAtIndex:indexPath.item];
//    
//    /**
//     *  iOS7-style sender name labels
//     */
//    if ([message.sender isEqualToString:self.sender]) {
//        return nil;
//    }
//    
//    if (indexPath.item - 1 > 0) {
//        JSQMessage *previousMessage = [self.messages objectAtIndex:indexPath.item - 1];
//        if ([[previousMessage sender] isEqualToString:message.sender]) {
//            return nil;
//        }
//    }
    
    /**
     *  Don't specify attributes to use the defaults.
     */
//    return [[NSAttributedString alloc] initWithString:message.sender];
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}


#pragma mark - JSQMessages collection view flow layout delegate

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  Each label in a cell has a `height` delegate method that corresponds to its text dataSource method
     */
    
    /**
     *  This logic should be consistent with what you return from `attributedTextForCellTopLabelAtIndexPath:`
     *  The other label height delegate methods should follow similarly
     *
     *  Show a timestamp for every 3rd message
     */
    if (indexPath.item % 3 == 0) {
        return kJSQMessagesCollectionViewCellLabelHeightDefault;
    }
    
    return 0.0f;
}


//- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
//                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
//{
//    /**
//     *  iOS7-style sender name labels
//     */
//    JSQMessage *currentMessage = [self.messages objectAtIndex:indexPath.item];
//    if ([[currentMessage senderId] isEqualToString:self.senderId]) {
//        return 0.0f;
//    }
//    
//    if (indexPath.item - 1 > 0) {
//        JSQMessage *previousMessage = [self.messages objectAtIndex:indexPath.item - 1];
//        if ([[previousMessage senderId] isEqualToString:[currentMessage senderId]]) {
//            return 0.0f;
//        }
//    }
//    
//    return kJSQMessagesCollectionViewCellLabelHeightDefault;
//}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
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

//- (void)collectionView:(JSQMessagesCollectionView *)collectionView
//                header:(JSQMessagesLoadEarlierHeaderView *)headerView didTapLoadEarlierMessagesButton:(UIButton *)sender
//{
//    NSLog(@"Load earlier messages!");
//    
//    __block id chatvc = self;
//    dispatch_queue_t messageQueue = dispatch_queue_create("Message Queue",NULL);
//    
//    NSUInteger numberOfMessagesToLoad;
//    NSInteger numberOfMessagesLeft = [self.messageObjects count]-[self.messages count];
//    NSLog(@"numberOfMessagesLeft: %lu", (unsigned long)numberOfMessagesLeft);
//    numberOfMessagesToLoad = ((int)numberOfMessagesLeft - 5) >= 0? 5: numberOfMessagesLeft;
//    NSLog(@"numberOfMessagesToLoad: %lu", (unsigned long)numberOfMessagesToLoad);
//
//    
//    for (PFObject *msg in [[self.messageObjects subarrayWithRange:NSMakeRange(numberOfMessagesLeft-numberOfMessagesToLoad, numberOfMessagesToLoad)] reverseObjectEnumerator]) {
//        
//        dispatch_async(messageQueue, ^{
//            
//            [chatvc createMessageAsync:msg];
//            
//        });
//    }
//}

//- (void)createMessageAsync:(PFObject *)msg
//{
//    [msg fetchIfNeeded];
//    NSLog(@"msg.createdAt: %@", msg.createdAt);
//    [msg[@"sender"] fetchIfNeeded];
//    NSLog(@"Sender: %@", msg[@"sender"]);
//    
//    JSQMessage *message = [[JSQMessage alloc] initWithText:msg[@"text"] sender:((PFUser *)msg[@"sender"]).username date:msg.createdAt];
//    
//    NSLock *arrayLock = [[NSLock alloc] init];
//    
//    /* NSMutableArray is not thread-safe */
//    [arrayLock lock];
//    
//    NSLog(@"Messages: %lu", (unsigned long)[self.messages count]);
//    
//    if (!self.messages) {
//        self.messages = [[NSMutableArray alloc] init];
//    }
//    
//    [self.messages addObject:message];
//    
//    NSLog(@"Array size: %lu", (unsigned long)[self.messages count]);
//    [arrayLock unlock];
//    
//    dispatch_async(dispatch_get_main_queue(), ^{
//        // Update the UI
//        NSLog(@"Message retrieved, refreshing view...");
//        
//        NSLog(@"Ready to present messages: %@", self.messages);
//        
//        [self finishReceivingMessage];
//        
////        [self.collectionView reloadData];
////        
////        [self scrollToBottomAnimated:YES];
//        
//        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.messages];
//        [[NSUserDefaults standardUserDefaults] setObject:data forKey:self.conversation.objectId];
//        [[NSUserDefaults standardUserDefaults] synchronize];
//        
//    });
//    
//}

- (void)viewWillDisappear:(BOOL)animated
{
    [[self navigationController] setNavigationBarHidden:YES animated:YES];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [timer invalidate];
    [super viewWillDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.progressHud = [MBProgressHUD showHUDAddedTo:self.collectionView animated:YES];
    [self.progressHud setLabelText:@"Loading..."];
    [self.progressHud setDimBackground:YES];
    
//    NSLog(@"[self.messages count]: %d", [self.messages count]);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(broughtToForeground) name:UIApplicationDidBecomeActiveNotification object:nil];

    
    [[self navigationController] setNavigationBarHidden:NO animated:YES];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                                                          target:self
                                                                                          action:@selector(closePressed:)];
    
    self.navigationItem.leftBarButtonItem.tintColor = kTraffleMainColor;
    
//    /* Check if there is an already existing conversation between users */
//    
//    self.conversation = nil;
//    
//    PFQuery * query = [PFQuery queryWithClassName:@"Conversation"];
//    [query whereKey:@"participants" containsAllObjectsInArray:[NSArray arrayWithObjects:[PFUser currentUser], self.recipient, nil]];
//    [query getFirstObjectInBackgroundWithBlock:^(PFObject *object, NSError *error) {
//        if(!error) {
//            self.conversation = object;
//            
//            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pushNotificationReceived:) name:@"pushNotification" object:nil];
//        
//            CLS_LOG(@"Conversation %@ exists, retrieveing its messages...", self.conversation.objectId);
//            PFQuery *messageQuery = [PFQuery queryWithClassName:@"Message"];
////            messageQuery.cachePolicy = kPFCachePolicyCacheOnly;
//            [messageQuery whereKey:@"conversation" equalTo:self.conversation];
//            [messageQuery orderByAscending:@"createdAt"];
//            [messageQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
//                if (error == nil) {
//                    NSLog(@"Array capacity: %lu", (unsigned long)[objects count]);
//                    self.messageObjects = [[NSMutableArray alloc] initWithArray:objects];
//                    
//                    dispatch_queue_t messageQueue = dispatch_queue_create("Message Queue",NULL);
//                    
//                    __block id chatvc = self;
//                    
////                    NSLog(@"[self.messageObjects count]: %@", [self.messageObjects subarrayWithRange:NSMakeRange([self.messageObjects count]-5, 5)]);
//                    
//
////                    for (PFObject *msg in [[self.messageObjects subarrayWithRange:NSMakeRange([self.messageObjects count]-5, 5)] reverseObjectEnumerator]) {
//                    
//                    NSMutableArray *storedMessages = [[NSMutableArray alloc] initWithArray:[NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:self.conversation.objectId]]];
//                    
//                    CLS_LOG(@"%d %d %d", [objects count], [storedMessages count], [PFInstallation currentInstallation].badge);
//                    
//                    if ([PFInstallation currentInstallation].badge < ([objects count] - [storedMessages count])) {
//                        [PFInstallation currentInstallation].badge = 0;
//                    } else {
//                        [PFInstallation currentInstallation].badge -= ([objects count] - [storedMessages count]);
//                    }
//                    [[PFInstallation currentInstallation] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
//                        if (!error) {
//                            [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[PFInstallation currentInstallation].badge];
//                        }
//                    }];
//                    
//                    self.messages = [[NSMutableArray alloc] initWithArray:storedMessages];
//
//                    if ([objects count] == [storedMessages count]) {
//                        self.messages = [[NSMutableArray alloc] initWithArray:storedMessages];
////                        [self.collectionView reloadData];
////                        [self scrollToBottomAnimated:NO];
//                        [self finishReceivingMessage];
//                        [self.progressHud hide:YES];
//                        self.collectionView.collectionViewLayout.springinessEnabled = YES;
//                    } else {
//
//                        [self.progressHud hide:YES];
//                        for (PFObject *msg in [self.messageObjects subarrayWithRange:NSMakeRange([storedMessages count], [self.messageObjects count] - [storedMessages count])]) {
//                        
//                            dispatch_async(messageQueue, ^{
//                                
//                                CLS_LOG("Creating new message: %@", msg);
//                                
//                                [chatvc createMessageAsync:msg];
//                            
//
//                            });
//                        }
//                    }
//                } else {
//                    NSLog(@"Error: %@", [error localizedDescription]);
//                }
//                
//            }];
//        }
//        
//    }];
    
//    [self.messageInputView.textView becomeFirstResponder];
    
    isLoading = NO;
    [self loadMessages];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (UIImageView *)avatarImageViewForRowAtIndexPath:(NSIndexPath *)indexPath sender:(NSString *)sender {
    return nil;
}

#pragma mark - JSMessagesViewDelegate implementation

- (BOOL)shouldDisplayTimestampForRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (BOOL)shouldPreventScrollToBottomWhileUserScrolling {
    return NO;
}

- (BOOL)allowsPanToDismissKeyboard {
    return YES;
}

- (void)closePressed:(UIBarButtonItem *)sender
{
    if (self.delegateModal) {
        [self.delegateModal didDismissChatViewController:self];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
}

-(void)pushNotificationReceived:(NSNotification *)pNotification
{
    
    if ([pNotification.userInfo[@"type"] isEqualToString:@"message"] &&
        [pNotification.userInfo[@"from"] isEqualToString:self.recipient.objectId])
    {
//        [PFInstallation currentInstallation].badge -= 1;
//        [[PFInstallation currentInstallation] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
//            if (!error) {
//                [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[PFInstallation currentInstallation].badge];
//            }
//        }];
    }
}

- (void) broughtToForeground
{
    [self finishReceivingMessage];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != actionSheet.cancelButtonIndex)
    {
        if (buttonIndex == 0)	ShouldStartCamera(self, YES);
        if (buttonIndex == 1)	ShouldStartPhotoLibrary(self, YES);
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *picture = info[UIImagePickerControllerEditedImage];
    [self sendMessage:@"[Picture message]" Picture:picture];
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end