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

//static NSString * const kJSQDemoAvatarNameCook = @"Tim Cook";
//static NSString * const kJSQDemoAvatarNameJobs = @"Jobs";
//static NSString * const kJSQDemoAvatarNameWoz = @"Steve Wozniak";

@interface Message ()

//@property (strong, nonatomic) NSDate *date;
//@property (strong, nonatomic) NSString *sender;
//@property (strong, nonatomic) NSString *text;

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

@property (strong, nonatomic) NSMutableArray *messageObjects;
@property (strong, nonatomic) MBProgressHUD *progressHud;

@end


@implementation ChatViewController

//#pragma mark - Demo setup
//
//- (void)setupTestModel
//{
//    /**
//     *  Load some fake messages for demo.
//     *
//     *  You should have a mutable array or orderedSet, or something.
//     */
//    self.messages = [[NSMutableArray alloc] initWithObjects:
//                     [[JSQMessage alloc] initWithText:@"Welcome to JSQMessages: A messaging UI framework for iOS." sender:self.sender date:[NSDate distantPast]],
//                     [[JSQMessage alloc] initWithText:@"It is simple, elegant, and easy to use. There are super sweet default settings, but you can customize like crazy." sender:kJSQDemoAvatarNameWoz date:[NSDate distantPast]],
//                     [[JSQMessage alloc] initWithText:@"It even has data detectors. You can call me tonight. My cell number is 123-456-7890. My website is www.hexedbits.com." sender:self.sender date:[NSDate distantPast]],
//                     [[JSQMessage alloc] initWithText:@"JSQMessagesViewController is nearly an exact replica of the iOS Messages App. And perhaps, better." sender:kJSQDemoAvatarNameJobs date:[NSDate date]],
//                     [[JSQMessage alloc] initWithText:@"It is unit-tested, free, and open-source." sender:kJSQDemoAvatarNameCook date:[NSDate date]],
//                     [[JSQMessage alloc] initWithText:@"Oh, and there's sweet documentation." sender:self.sender date:[NSDate date]],
//                     nil];
//    
//    /**
//     *  Create avatar images once.
//     *
//     *  Be sure to create your avatars one time and reuse them for good performance.
//     *
//     *  If you are not using avatars, ignore this.
//     */
//    CGFloat outgoingDiameter = self.collectionView.collectionViewLayout.outgoingAvatarViewSize.width;
//    
//    UIImage *jsqImage = [JSQMessagesAvatarFactory avatarWithUserInitials:@"JSQ"
//                                                         backgroundColor:[UIColor colorWithWhite:0.85f alpha:1.0f]
//                                                               textColor:[UIColor colorWithWhite:0.60f alpha:1.0f]
//                                                                    font:[UIFont systemFontOfSize:14.0f]
//                                                                diameter:outgoingDiameter];
//    
//    CGFloat incomingDiameter = self.collectionView.collectionViewLayout.incomingAvatarViewSize.width;
//    
//    UIImage *cookImage = [JSQMessagesAvatarFactory avatarWithImage:[UIImage imageNamed:@"demo_avatar_cook"]
//                                                          diameter:incomingDiameter];
//    
//    UIImage *jobsImage = [JSQMessagesAvatarFactory avatarWithImage:[UIImage imageNamed:@"demo_avatar_jobs"]
//                                                          diameter:incomingDiameter];
//    
//    UIImage *wozImage = [JSQMessagesAvatarFactory avatarWithImage:[UIImage imageNamed:@"demo_avatar_woz"]
//                                                         diameter:incomingDiameter];
//    self.avatars = @{ self.sender : jsqImage,
//                      kJSQDemoAvatarNameCook : cookImage,
//                      kJSQDemoAvatarNameJobs : jobsImage,
//                      kJSQDemoAvatarNameWoz : wozImage };
//    
//    /**
//     *  Change to add more messages for testing
//     */
//    NSUInteger messagesToAdd = 0;
//    NSArray *copyOfMessages = [self.messages copy];
//    for (NSUInteger i = 0; i < messagesToAdd; i++) {
//        [self.messages addObjectsFromArray:copyOfMessages];
//    }
//    
//    /**
//     *  Change to YES to add a super long message for testing
//     *  You should see "END" twice
//     */
//    BOOL addREALLYLongMessage = NO;
//    if (addREALLYLongMessage) {
//        JSQMessage *reallyLongMessage = [JSQMessage messageWithText:@"Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur? END Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur? END" sender:self.sender];
//        [self.messages addObject:reallyLongMessage];
//    }
//}



#pragma mark - View lifecycle

/**
 *  Override point for customization.
 *
 *  Customize your view.
 *  Look at the properties on `JSQMessagesViewController` to see what is possible.
 *
 *  Customize your layout.
 *  Look at the properties on `JSQMessagesCollectionViewFlowLayout` to see what is possible.
 */

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

//    self.view.userInteractionEnabled = YES;
//    self.automaticallyScrollsToMostRecentMessage = YES;
//    self.showLoadEarlierMessagesHeader = YES;
    
    UIFont *avenirFont = [UIFont fontWithName:@"AvenirNextCondensed-Regular" size:20.5f];
    self.collectionView.collectionViewLayout.messageBubbleFont = avenirFont;
    
    self.title = self.recipient[@"Name"];
//    self.messageInputView.textView.placeHolder = NSLocalizedString(@"Your message", @"");
    self.sender = [PFUser currentUser].username;
    
    CGFloat outgoingDiameter = self.collectionView.collectionViewLayout.outgoingAvatarViewSize.width;
    
    PFFile *file = [PFUser currentUser][@"Photo"];

    NSLog(@"Getting current user photo...");
    
    [file getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
        if (!error) {
            
            UIImage *img = [UIImage imageWithData:data];
            
            NSLog(@"image.size.width: %f, image.size.height: %f", img.size.width, img.size.height);
            NSLog(@"%f", outgoingDiameter);
            
//            UIImage *senderAvatar = [self blendImagesWithBackground:[UIImage imageNamed:@"ci_profile_mask_alpha"] foreground:[UIImage imageWithData:data]];
            
//            UIImage *senderAvatar = [UIImage imageNamed:@"ci_profile_mask_alpha"];
            
            UIImage *senderAvatar = [UIImage imageWithData:data];
            
            UIImage *senderImage = [JSQMessagesAvatarFactory avatarWithImage:senderAvatar
                                                                diameter:outgoingDiameter];
            
            NSLog(@"image.size.width: %f, image.size.height: %f", senderImage.size.width, senderImage.size.height);
            
            NSLog(@"Getting current user photo... done");

            [self.recipient fetchIfNeeded];
            
            PFFile *file = self.recipient[@"Photo"];
            
            NSLog(@"Getting matched user photo...");
            
            [file getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
                if (!error) {
                    
                    NSLog(@"Getting matched user photo... done");
            
                    UIImage *recipientImage = [JSQMessagesAvatarFactory avatarWithImage:[UIImage imageWithData:data]
                                                                       diameter:outgoingDiameter];
                    
                    
            
                    self.avatars = @{ self.sender : senderImage,
                                      self.recipient.username: recipientImage};
                    
                    
                    
                }
            }];
        }
    }];
    

    
//    self.title = @"JSQMessages";
//    
//    self.sender = @"Jesse Squires";
//    
//    [self setupTestModel];
    
    /**
     *  Remove camera button since media messages are not yet implemented
     */
        self.inputToolbar.contentView.leftBarButtonItem = nil;

    
    /**
     *  Create bubble images.
     *
     *  Be sure to create your avatars one time and reuse them for good performance.
     *
     */
    self.outgoingBubbleImageView = [JSQMessagesBubbleImageFactory
                                    outgoingMessageBubbleImageViewWithColor:kTraffleMainColor];
    
    self.incomingBubbleImageView = [JSQMessagesBubbleImageFactory
                                    incomingMessageBubbleImageViewWithColor:[UIColor whiteColor]];
    
//    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"typing"]
//                                                                              style:UIBarButtonItemStyleBordered
//                                                                             target:self
//                                                                             action:@selector(receiveMessagePressed:)];
    
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    /**
     *  Enable/disable springy bubbles, default is YES.
     *  For best results, toggle from `viewDidAppear:`
     */
    self.collectionView.collectionViewLayout.springinessEnabled = NO;
}



#pragma mark - Actions

- (void)receiveMessagePressed:(UIBarButtonItem *)sender
{
    /**
     *  The following is simply to simulate received messages for the demo.
     *  Do not actually do this.
     */
    
    
    /**
     *  Show the tpying indicator
     */
    self.showTypingIndicator = !self.showTypingIndicator;
    
    JSQMessage *copyMessage = [[self.messages lastObject] copy];
    
    if (!copyMessage) {
        return;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        NSMutableArray *copyAvatars = [[self.avatars allKeys] mutableCopy];
        [copyAvatars removeObject:self.sender];
        
        PFQuery *query = [PFUser query];
        PFUser *cuser = (PFUser*)[query getObjectWithId:@"ABJavePdyc"];
        
        copyMessage.sender = cuser.username;
        
        NSLog(@"Copy message: %@ %@", copyMessage, copyMessage.sender);
        
        /**
         *  This you should do upon receiving a message:
         *
         *  1. Play sound (optional)
         *  2. Add new id<JSQMessageData> object to your data source
         *  3. Call `finishReceivingMessage`
         */
        [JSQSystemSoundPlayer jsq_playMessageReceivedSound];
        [self.messages addObject:copyMessage];
        [self finishReceivingMessage];
    });
}

#pragma mark - JSQMessagesViewController method overrides

- (void)didPressSendButton:(UIButton *)button
           withMessageText:(NSString *)text
                    sender:(NSString *)sender
                      date:(NSDate *)date
{
//    NSLog(@"Text: '%@'", text);
    /**
     *  Sending a message. Your implementation of this method should do *at least* the following:
     *
     *  1. Play sound (optional)
     *  2. Add new id<JSQMessageData> object to your data source
     *  3. Call `finishSendingMessage`
     */
    
    button.enabled = NO;
    
    [JSQSystemSoundPlayer jsq_playMessageSentSound];
    
    Message *message = [[Message alloc] initWithText:text sender:[PFUser currentUser] recipient:self.recipient conversation:self.conversation];
    
    NSLog(@"Saving message");
    
    [message saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            JSQMessage *msg  = [[JSQMessage alloc] initWithText:message.text sender:message.sender date:message.date];
            [self.messages addObject:msg];
            
            [self.conversation incrementKey:@"messageCount"];
            [self.conversation saveInBackground];
            
            NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSString stringWithFormat:@"New message from %@", [PFUser currentUser][@"Name"]], @"alert",
                                  @"Increment", @"badge",
                                  @"message", @"type",
                                  @1, @"content-available",
                                  [NSString stringWithFormat:@"%@", [PFUser currentUser].objectId], @"from",
                                  text, @"text",
                                  nil];
            
            // Now we’ll need to query all saved installations to find those of our recipients
            // Create our Installation query using the self.recipients array we already have
            PFQuery *pushQuery = [PFInstallation query];
            [pushQuery whereKey:@"installationUser" equalTo:self.recipient.objectId];
            
            // Send push notification to our query
            PFPush *push = [[PFPush alloc] init];
            [push setQuery:pushQuery];
            [push setData:data];
            [push sendPushInBackground];
            
            NSLog(@"Added message '%@', %@, %@", message.text, message.sender, message.date);
            
            NSData *msgData = [NSKeyedArchiver archivedDataWithRootObject:self.messages];
            [[NSUserDefaults standardUserDefaults] setObject:msgData forKey:self.conversation.objectId];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            [self finishSendingMessage];
            button.enabled = YES;
            
        } else {
            NSLog(@"Error: %@", [error localizedDescription]);
        }
    }];
    
//    JSQMessage *message2 = [[JSQMessage alloc] initWithText:@"test" sender:@"Bob" date:[[NSDate alloc] init]];
//    [self.messages addObject:message2];
    
//    [self finishSendingMessage];
    
    
}

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
    return [self.messages objectAtIndex:indexPath.item];
}

- (UIImageView *)collectionView:(JSQMessagesCollectionView *)collectionView bubbleImageViewForItemAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  You may return nil here if you do not want bubbles.
     *  In this case, you should set the background color of your collection view cell's textView.
     */
    
    /**
     *  Reuse created bubble images, but create new imageView to add to each cell
     *  Otherwise, each cell would be referencing the same imageView and bubbles would disappear from cells
     */
    
    NSLog(@"bubble: %ld", (long)indexPath.row);
    
    JSQMessage *message = [self.messages objectAtIndex:indexPath.item];
    
    
    
    if ([message.sender isEqualToString:self.sender]) {
        return [[UIImageView alloc] initWithImage:self.outgoingBubbleImageView.image
                                 highlightedImage:self.outgoingBubbleImageView.highlightedImage];
    }
    
    return [[UIImageView alloc] initWithImage:self.incomingBubbleImageView.image
                             highlightedImage:self.incomingBubbleImageView.highlightedImage];
}

#pragma mark - UICollectionView DataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    NSLog(@"rows: %lu", (unsigned long)[self.messages count]);
    return [self.messages count];
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
    
    JSQMessage *msg = [self.messages objectAtIndex:indexPath.item];
    
    if ([msg.sender isEqualToString:self.sender]) {
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

- (UIImageView *)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageViewForItemAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  Return `nil` here if you do not want avatars.
     *  If you do return `nil`, be sure to do the following in `viewDidLoad`:
     *
     *  self.collectionView.collectionViewLayout.incomingAvatarViewSize = CGSizeZero;
     *  self.collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSizeZero;
     *
     *  It is possible to have only outgoing avatars or only incoming avatars, too.
     */
    
    /**
     *  Reuse created avatar images, but create new imageView to add to each cell
     *  Otherwise, each cell would be referencing the same imageView and avatars would disappear from cells
     *
     *  Note: these images will be sized according to these values:
     *
     *  self.collectionView.collectionViewLayout.incomingAvatarViewSize
     *  self.collectionView.collectionViewLayout.outgoingAvatarViewSize
     *
     *  Override the defaults in `viewDidLoad`
     */
    JSQMessage *message = [self.messages objectAtIndex:indexPath.item];
    
    UIImage *avatarImage = [self.avatars objectForKey:message.sender];
    return [[UIImageView alloc] initWithImage:avatarImage];
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  This logic should be consistent with what you return from `heightForCellTopLabelAtIndexPath:`
     *  The other label text delegate methods should follow a similar pattern.
     *
     *  Show a timestamp for every 3rd message
     */
    if (indexPath.item % 3 == 0) {
        JSQMessage *message = [self.messages objectAtIndex:indexPath.item];
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


- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  iOS7-style sender name labels
     */
    JSQMessage *currentMessage = [self.messages objectAtIndex:indexPath.item];
    if ([[currentMessage sender] isEqualToString:self.sender]) {
        return 0.0f;
    }
    
    if (indexPath.item - 1 > 0) {
        JSQMessage *previousMessage = [self.messages objectAtIndex:indexPath.item - 1];
        if ([[previousMessage sender] isEqualToString:[currentMessage sender]]) {
            return 0.0f;
        }
    }
    
    return kJSQMessagesCollectionViewCellLabelHeightDefault;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
                header:(JSQMessagesLoadEarlierHeaderView *)headerView didTapLoadEarlierMessagesButton:(UIButton *)sender
{
    NSLog(@"Load earlier messages!");
    
    __block id chatvc = self;
    dispatch_queue_t messageQueue = dispatch_queue_create("Message Queue",NULL);
    
    NSUInteger numberOfMessagesToLoad;
    NSInteger numberOfMessagesLeft = [self.messageObjects count]-[self.messages count];
    NSLog(@"numberOfMessagesLeft: %lu", (unsigned long)numberOfMessagesLeft);
    numberOfMessagesToLoad = ((int)numberOfMessagesLeft - 5) >= 0? 5: numberOfMessagesLeft;
    NSLog(@"numberOfMessagesToLoad: %lu", (unsigned long)numberOfMessagesToLoad);

    
    for (PFObject *msg in [[self.messageObjects subarrayWithRange:NSMakeRange(numberOfMessagesLeft-numberOfMessagesToLoad, numberOfMessagesToLoad)] reverseObjectEnumerator]) {
        
        dispatch_async(messageQueue, ^{
            
            [chatvc createMessageAsync:msg];
            
        });
    }
}

- (void)createMessageAsync:(PFObject *)msg
{
    [msg fetchIfNeeded];
    NSLog(@"msg.createdAt: %@", msg.createdAt);
    [msg[@"sender"] fetchIfNeeded];
    NSLog(@"Sender: %@", msg[@"sender"]);
    
    JSQMessage *message = [[JSQMessage alloc] initWithText:msg[@"text"] sender:((PFUser *)msg[@"sender"]).username date:msg.createdAt];
    
    NSLock *arrayLock = [[NSLock alloc] init];
    
    /* NSMutableArray is not thread-safe */
    [arrayLock lock];
    
    NSLog(@"Messages: %lu", (unsigned long)[self.messages count]);
    
    if (!self.messages) {
        self.messages = [[NSMutableArray alloc] init];
    }
    
    [self.messages addObject:message];
    
    NSLog(@"Array size: %lu", (unsigned long)[self.messages count]);
    [arrayLock unlock];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Update the UI
        NSLog(@"Message retrieved, refreshing view...");
        
        NSLog(@"Ready to present messages: %@", self.messages);
        
        [self.collectionView reloadData];
        
        [self scrollToBottomAnimated:YES];
        
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.messages];
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:self.conversation.objectId];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
    });
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[self navigationController] setNavigationBarHidden:YES animated:YES];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super viewWillDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.progressHud = [MBProgressHUD showHUDAddedTo:self.collectionView animated:YES];
    [self.progressHud setLabelText:@"Loading..."];
    [self.progressHud setDimBackground:YES];
    
    NSLog(@"[self.messages count]: %d", [self.messages count]);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(broughtToForeground) name:UIApplicationDidBecomeActiveNotification object:nil];

    
    [[self navigationController] setNavigationBarHidden:NO animated:YES];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                                                          target:self
                                                                                          action:@selector(closePressed:)];
    
    self.navigationItem.leftBarButtonItem.tintColor = kTraffleMainColor;
    
    /* Check if there is an already existing conversation between users */
    
    self.conversation = nil;
    
    PFQuery * query = [PFQuery queryWithClassName:@"Conversation"];
    [query whereKey:@"participants" containsAllObjectsInArray:[NSArray arrayWithObjects:[PFUser currentUser], self.recipient, nil]];
    [query getFirstObjectInBackgroundWithBlock:^(PFObject *object, NSError *error) {
        if(!error) {
            self.conversation = object;
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pushNotificationReceived:) name:@"pushNotification" object:nil];
        
            CLS_LOG(@"Conversation %@ exists, retrieveing its messages...", self.conversation.objectId);
            PFQuery *messageQuery = [PFQuery queryWithClassName:@"Message"];
//            messageQuery.cachePolicy = kPFCachePolicyCacheOnly;
            [messageQuery whereKey:@"conversation" equalTo:self.conversation];
            [messageQuery orderByAscending:@"createdAt"];
            [messageQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
                if (error == nil) {
                    NSLog(@"Array capacity: %lu", (unsigned long)[objects count]);
                    self.messageObjects = [[NSMutableArray alloc] initWithArray:objects];
                    
                    dispatch_queue_t messageQueue = dispatch_queue_create("Message Queue",NULL);
                    
                    __block id chatvc = self;
                    
//                    NSLog(@"[self.messageObjects count]: %@", [self.messageObjects subarrayWithRange:NSMakeRange([self.messageObjects count]-5, 5)]);
                    

//                    for (PFObject *msg in [[self.messageObjects subarrayWithRange:NSMakeRange([self.messageObjects count]-5, 5)] reverseObjectEnumerator]) {
                    
                    NSMutableArray *storedMessages = [[NSMutableArray alloc] initWithArray:[NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:self.conversation.objectId]]];
                    
                    CLS_LOG(@"%d %d %d", [objects count], [storedMessages count], [PFInstallation currentInstallation].badge);
                    
                    if ([PFInstallation currentInstallation].badge < ([objects count] - [storedMessages count])) {
                        [PFInstallation currentInstallation].badge = 0;
                    } else {
                        [PFInstallation currentInstallation].badge -= ([objects count] - [storedMessages count]);
                    }
                    [[PFInstallation currentInstallation] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                        if (!error) {
                            [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[PFInstallation currentInstallation].badge];
                        }
                    }];
                    
                    self.messages = [[NSMutableArray alloc] initWithArray:storedMessages];

                    if ([objects count] == [storedMessages count]) {
                        self.messages = [[NSMutableArray alloc] initWithArray:storedMessages];
                        [self.collectionView reloadData];
                        [self scrollToBottomAnimated:NO];
                        [self.progressHud hide:YES];
                        self.collectionView.collectionViewLayout.springinessEnabled = YES;
                    } else {

                        [self.progressHud hide:YES];
                        for (PFObject *msg in [self.messageObjects subarrayWithRange:NSMakeRange([storedMessages count], [self.messageObjects count] - [storedMessages count])]) {
                        
                            dispatch_async(messageQueue, ^{
                                
                                CLS_LOG("Creating new message: %@", msg);
                                
                                [chatvc createMessageAsync:msg];
                            

                            });
                        }
                    }
                } else {
                    NSLog(@"Error: %@", [error localizedDescription]);
                }
                
            }];
        }
        
    }];
    
//    [self.messageInputView.textView becomeFirstResponder];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSLog(@"number of rows: %lu", (unsigned long)[self.messages count]);
    return [self.messages count];
}

#pragma mark - JSMessagesViewDataSource implementation

//- (id <JSMessageData>)messageForRowAtIndexPath:(NSIndexPath *)indexPath {
//    JSMessage *message = self.messages[(NSUInteger) indexPath.row];
//    return message;
//}

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

/*- (UIButton *)sendButtonForInputView {
 return nil;
 }*/

/*- (NSString *)customCellIdentifierForRowAtIndexPath:(NSIndexPath *)indexPath {
 return nil;
 }*/

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
        NSLog(@"New message: %@", pNotification.userInfo);
//        Message *message = [[Message alloc] initWithText:pNotification.userInfo[@"text"] sender:self.recipient recipient:[PFUser currentUser] conversation:self.conversation];
        JSQMessage *message = [[JSQMessage alloc] initWithText:pNotification.userInfo[@"text"] sender:self.recipient.username date:[NSDate date]];
        
        [self.messages addObject:message];
        
        [PFInstallation currentInstallation].badge -= 1;
        NSLog(@"pushNotificationReceived badge: %d", [PFInstallation currentInstallation].badge);
        [[PFInstallation currentInstallation] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            if (!error) {
                [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[PFInstallation currentInstallation].badge];
            }
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            // Update the UI

            [self.collectionView reloadData];
            [self scrollToBottomAnimated:YES];
        });
    }
}

- (void) broughtToForeground
{
    [self.collectionView reloadData];
    [self scrollToBottomAnimated:YES];
}

@end