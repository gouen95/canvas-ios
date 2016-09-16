//
//  CBIMessageParticipantsViewModel.m
//  iCanvas
//
//  Created by derrick on 11/27/13.
//  Copyright (c) 2013 Instructure. All rights reserved.
//

#import "CBIMessageParticipantsViewModel.h"
#import "CBIMessageParticipantsCell.h"
#import "EXTScope.h"
#import "NSArray_in_additions.h"
#import "ConversationRecipientsController.h"
@import JSTokenField;
#import <CanvasKit1/CanvasKit1.h>
@import CanvasKeymaster;

@interface CBIMessageParticipantsViewModel () <ConversationRecipientsControllerDelegate>
@property (nonatomic) UIPopoverController *popover;
@end

@implementation CBIMessageParticipantsViewModel {
    RACSubject *_recipientsAddedSubject;
}

- (id)init
{
    self = [super init];
    if (self) {
        _pendingRecipients = @[];
        _recipientsAddedSubject = [RACSubject subject];
    }
    return self;
}

- (void)showRecipientsPopoverInView:(UIView *)parent fromButton:(UIView *)button
{
    CKIConversation *convo = self.model;
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"ConversationRecipients" bundle:[NSBundle bundleForClass:[self class]]];
    UINavigationController *navController = [storyboard instantiateInitialViewController];
    ConversationRecipientsController *recipientsController = (navController.viewControllers)[0];
    recipientsController.selectedRecipients = self.pendingRecipients;
    NSDictionary *participantsByID = [NSDictionary dictionaryWithObjects:convo.participants forKeys:[convo.participants valueForKey:@"id"]];
    recipientsController.staticResults = [[[[convo.audienceIDs.rac_sequence filter:^BOOL(id value) {
        return participantsByID[value] != nil;
    }] map:^id(id value) {
        return participantsByID[value];
    }] map:^id(CKIUser *user) {
        NSDictionary *infoDict = [user JSONDictionary];
        return [CKIConversationRecipient modelFromJSONDictionary:infoDict];
    }] array];
    recipientsController.delegate = self;
    if (convo.audienceIDs.count == 1) {
        recipientsController.allowsSelection = NO;
        recipientsController.showsTokenField = NO;
        recipientsController.showsCheckmarksForSelectedItems = NO;
    }
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        self.popover = [[UIPopoverController alloc] initWithContentViewController:navController];
        [self.popover presentPopoverFromRect:button.frame inView:parent permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    } else {
        [self.viewControllerToPresentFrom presentViewController:navController animated:YES completion:nil];
    }
    
    [recipientsController.tokenField becomeFirstResponder];
}

#pragma mark - ConversationRecipientsViewControllerDelegate

- (BOOL)isRecipientSelectable:(CKIConversationRecipient *)recipient
{
    if ([[CKIClient currentClient].currentUser.id isEqualToString:recipient.id]) {
        return NO;
    }
    
    NSArray *allParticipants = [self.model.participants valueForKeyPath:@"id"];
    return ![allParticipants containsObject:recipient.id];
}

- (BOOL)isRecipientSelected:(CKIConversationRecipient *)recipient
{
    return [self.pendingRecipients containsObject:recipient] || [self.model.audienceIDs containsObject:recipient.id];
}

- (void)recipientsController:(ConversationRecipientsController *)controller saveRecipients:(NSArray *)recipients
{
    if (self.model) {
        [[[CKIClient currentClient] addNewRecipientsIDs:[recipients valueForKeyPath:@"id"] toConversation:self.model] subscribeCompleted:^{
            [self signalNewRecipients];
            self.pendingRecipients = @[];
        }];
    } else {
        self.pendingRecipients = recipients;
    }
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        [self.popover dismissPopoverAnimated:YES];
    } else {
        [self.viewControllerToPresentFrom dismissViewControllerAnimated:YES completion:nil];
    }
}

- (RACSignal *)recipientsAddedSignal {
    return _recipientsAddedSubject;
}

- (void)signalNewRecipients {
    [_recipientsAddedSubject sendNext:[RACUnit defaultUnit]];
}

@end
