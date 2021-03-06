//
//  SocializeUIShareCreator.m
//  SocializeSDK
//
//  Created by Nathaniel Griswold on 2/21/12.
//  Copyright (c) 2012 Socialize, Inc. All rights reserved.
//

#import "SocializeUIShareCreator.h"
#import "_Socialize.h"
#import "SocializeShare.h"
#import "SocializeComposeMessageViewController.h"
#import "SocializeUIDisplayProxy.h"
#import "UINavigationController+Socialize.h"
#import "MFMessageComposeViewController+BlocksKit.h"
#import "MFMailComposeViewController+BlocksKit.h"
#import "UIActionSheet+BlocksKit.h"
#import "UIAlertView+BlocksKit.h"
#import "SocializeUIShareOptions.h"
#import "SocializeTwitterAuthenticator.h"
#import "SocializeFacebookAuthenticator.h"
#import "NSError+Socialize.h"
#import "SocializeFacebookWallPoster.h"
#import "SocializePreprocessorUtilities.h"
#import "SocializeThirdPartyFacebook.h"
#import "SocializeThirdPartyTwitter.h"
#import "SocializeShareCreator.h"

@interface SocializeUIShareCreator ()
- (void)showSMSComposer;
- (void)tryToFinishCreatingShare;
- (NSString*)entityNameOrKey;
@property (nonatomic, assign) BOOL finishedServerCreate;
@property (nonatomic, assign) BOOL selectedShareMedium;
@property (nonatomic, assign) BOOL compositionComplete;
@end

@implementation SocializeUIShareCreator
@synthesize finishedServerCreate = finishedServerCreate_;
@synthesize selectedShareMedium = selectedShareMedium_;
@synthesize compositionComplete = compositionComplete_;

SYNTH_CLASS_GETTER(MFMessageComposeViewController, messageComposerClass)
SYNTH_CLASS_GETTER(MFMailComposeViewController, mailComposerClass)

@synthesize shareObject = shareObject;
@synthesize options = options_;
@synthesize application = application_;

- (void)dealloc {
    self.shareObject = nil;
    self.options = nil;
    self.application = nil;
    
    [super dealloc];
}

+ (void)createShareWithOptions:(SocializeUIShareOptions*)options
                       display:(id)display
                       success:(void(^)())success
                       failure:(void(^)(NSError *error))failure {
    
    SocializeUIShareCreator *share = [[[self alloc] initWithOptions:options display:display] autorelease];
    share.successBlock = success;
    share.failureBlock = failure;
    
    [SocializeAction executeAction:share];
}

+ (void)createShareWithOptions:(SocializeUIShareOptions*)options
                  displayProxy:(SocializeUIDisplayProxy*)proxy
                       success:(void(^)())success
                       failure:(void(^)(NSError *error))failure {
    SocializeUIShareCreator *share = [[[self alloc] initWithOptions:options displayProxy:proxy] autorelease];
    share.successBlock = success;
    share.failureBlock = failure;
    [SocializeAction executeAction:share];
}

- (id)initWithOptions:(SocializeUIShareOptions *)options displayProxy:(SocializeUIDisplayProxy *)displayProxy display:(id<SocializeUIDisplay>)display {
    if (self = [super initWithOptions:options displayProxy:displayProxy display:display]) {
        self.shareObject = [[[SocializeShare alloc] init] autorelease];
        self.shareObject.entity = options.entity;
        self.options = options;
    }
    
    return self;
}

- (UIApplication*)application {
    if (application_ == nil) {
        application_ = [[UIApplication sharedApplication] retain];
    }
    return application_;
}

- (void)createShareOnSocializeServer {
    if (self.shareObject.medium == SocializeShareMediumTwitter) {
        [self.shareObject setThirdParties:[NSArray arrayWithObject:@"twitter"]];
    }
    
    [self.socialize createShare:self.shareObject];
}

- (void)service:(SocializeService *)service didCreate:(id<SocializeObject>)object {
    NSAssert([object conformsToProtocol:@protocol(SocializeShare)], @"bad object");
    self.shareObject = (id<SocializeShare>)object;
    self.finishedServerCreate = YES;
    [self tryToFinishCreatingShare];
}

- (void)service:(SocializeService *)service didFail:(NSError *)error {
    [self failWithError:error];
}

- (NSError*)defaultError {
    return [NSError defaultSocializeErrorForCode:SocializeErrorShareCreationFailed];
}

- (void)showMessageComposition {
    SocializeComposeMessageViewController *composition = [[[SocializeComposeMessageViewController alloc] initWithEntityUrlString:self.shareObject.entity.key] autorelease];
    composition.delegate = self;
    if (self.shareObject.medium == SocializeShareMediumTwitter) {
        composition.title = @"Twitter Share";
    } else if (self.shareObject.medium == SocializeShareMediumFacebook) {
        composition.title = @"Facebook Share";
    }
    UINavigationController *nav = [UINavigationController socializeNavigationControllerWithRootViewController:composition];
    [self.displayProxy presentModalViewController:nav];
}

- (BOOL)canSendText {
    return [self.messageComposerClass canSendText];
}

- (NSString*)defaultSMSMessage {
    NSString *entityURL = [self entityURLForThirdParty:@"sms"];
    NSString *applicationURL = [self applicationURLForThirdParty:@"sms"];
    return [self defaultMessageForEntityURL:entityURL applicationURL:applicationURL];
}

- (void)showSMSComposer {
    if (![self canSendText]) {
        [self failWithError:[NSError defaultSocializeErrorForCode:SocializeErrorSMSNotAvailable]];
    }
    
    MFMessageComposeViewController *composer = [[[self.messageComposerClass alloc] init] autorelease];
    [composer setBody:[self defaultSMSMessage]];
    
    __block __typeof__(self) weakSelf = self;
    __block __typeof__(composer) weakComposer = composer;
    composer.sz_completionBlock = ^(MessageComposeResult result) {
        [weakSelf.displayProxy dismissModalViewController:weakComposer];

        switch (result) {
            case MessageComposeResultFailed:
                [weakSelf failWithError:nil];
                break;
            case MessageComposeResultCancelled:
                [weakSelf failWithError:[NSError defaultSocializeErrorForCode:SocializeErrorShareCancelledByUser]];
                break;
            case MessageComposeResultSent:
                self.compositionComplete = YES;
                [weakSelf tryToFinishCreatingShare];
                break;
        }
    };
    
    [self.displayProxy presentModalViewController:composer];
}

- (void)showUnconfiguredEmailAlert {
    UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Mail is not Configured" message:@"Please configure at least one mail account before sharing via email."] autorelease];
    
    __block __typeof__(self) weakSelf = self;
    [alert addButtonWithTitle:@"Add Account" handler:^{
        [weakSelf.application openURL:[NSURL URLWithString:@"prefs:root=ACCOUNT_SETTINGS"]];
        [weakSelf failWithError:[NSError defaultSocializeErrorForCode:SocializeErrorEmailNotAvailable]];
    }];
    [alert setCancelButtonWithTitle:@"Cancel" handler:^{
        [weakSelf failWithError:[NSError defaultSocializeErrorForCode:SocializeErrorEmailNotAvailable]];
    }];
    [weakSelf.displayProxy showAlertView:alert];
}

- (BOOL)canSendMail {
    return [self.mailComposerClass canSendMail];
}

- (NSString*)defaultMessageForEntityURL:(NSString*)entityURL applicationURL:(NSString*)applicationURL {
    id<SocializeEntity> e = self.shareObject.entity;
    
    NSMutableString *msg = [NSMutableString stringWithString:@"I thought you would find this interesting: "];
    
    if ([e.name length] > 0) {
        [msg appendFormat:@"%@ ", e.name];
    }
    
    NSString *applicationName = [self.shareObject.application name];
    
    [msg appendFormat:@"%@\n\nSent from %@ (%@)", entityURL, applicationName, applicationURL];
    
    return msg;    
}

- (NSString*)defaultEmailMessageBody {
    NSString *entityURL = [self entityURLForThirdParty:@"email"];
    NSString *applicationURL = [self applicationURLForThirdParty:@"email"];
    return [self defaultMessageForEntityURL:entityURL applicationURL:applicationURL];
}

- (NSString*)defaultEmailSubject {
    return [self entityNameOrKey];
}

- (void)showEmailComposition {
    MFMailComposeViewController *composer = [[[self.mailComposerClass alloc] init] autorelease];
    
    __block __typeof__(self) weakSelf = self;
    __block __typeof__(composer) weakComposer = composer;
    composer.sz_completionBlock = ^(MFMailComposeResult result, NSError *error)
    {
        [weakSelf.displayProxy dismissModalViewController:weakComposer];
        // Notifies users about errors associated with the interface
        switch (result)
        {
            case MFMailComposeResultCancelled:
            case MFMailComposeResultSaved:
                [weakSelf failWithError:[NSError defaultSocializeErrorForCode:SocializeErrorShareCancelledByUser]];
                break;
            case MFMailComposeResultFailed:
                [weakSelf failWithError:nil];
                break;
            case MFMailComposeResultSent:
                self.compositionComplete = YES;
                [weakSelf tryToFinishCreatingShare];
                break;
        }
    };
    [composer setSubject:[self entityNameOrKey]];
    [composer setMessageBody:[self defaultEmailMessageBody] isHTML:NO];
    
    [self.displayProxy presentModalViewController:composer];
}

-(void)tryToShowEmailComposition
{
    if ([self canSendMail]) {
        // Show an MFMailComposeViewController
        [self showEmailComposition];
    } else {
        // Direct user to settings
        [self showUnconfiguredEmailAlert];
    }
}

- (void)selectShareMedium:(SocializeShareMedium)shareMedium {
    self.selectedShareMedium = YES;
    self.shareObject.medium = shareMedium;
    [self tryToFinishCreatingShare];
}

- (void)showShareActionSheet {
    UIActionSheet *actionSheet = [UIActionSheet sheetWithTitle:nil];

    __block __typeof__(self) weakSelf = self;
    
    if([SocializeThirdPartyTwitter available]) {
        [actionSheet addButtonWithTitle:@"Share via Twitter" handler:^{
            [weakSelf selectShareMedium:SocializeShareMediumTwitter];
        }];
    }

    if([SocializeThirdPartyFacebook available]) {
        [actionSheet addButtonWithTitle:@"Share via Facebook" handler:^{
            [weakSelf selectShareMedium:SocializeShareMediumFacebook];
        }];
    }

    [actionSheet addButtonWithTitle:@"Share via Email" handler:^{
        [weakSelf selectShareMedium:SocializeShareMediumEmail];
    }];

    if ([self canSendText]) {
        [actionSheet addButtonWithTitle:@"Share via SMS" handler:^{
            [weakSelf selectShareMedium:SocializeShareMediumSMS];
        }];
    }
    
    [actionSheet setCancelButtonWithTitle:nil handler:^{
        [weakSelf failWithError:[NSError defaultSocializeErrorForCode:SocializeErrorShareCancelledByUser]];
    }];
    
    [self.displayProxy showActionSheet:actionSheet];
}

- (NSString*)entityNameOrKey {
    NSString *title = self.shareObject.entity.name;
    if ([title length] == 0) {
        title = self.shareObject.entity.key;
    }
    
    return title;
}

- (void)showCompositionInterface {
    switch (self.shareObject.medium) {
        case SocializeShareMediumSMS:
            [self showSMSComposer];
            break;
        case SocializeShareMediumFacebook:
        case SocializeShareMediumTwitter:
            [self showMessageComposition];
            break;
        case SocializeShareMediumEmail:
            [self tryToShowEmailComposition];
            break;
            
        default:
            NSAssert(NO, @"Unsupported medium %@", [self.shareObject medium]);
            break;
    }

}

- (void)authenticateViaTwitter {
    SocializeTwitterAuthOptions *options = self.options.twitterAuthOptions;
    if (options == nil) {
        options = [SocializeTwitterAuthOptions options];
    }
    options.doNotPromptForPermission = YES;
    
    [SocializeTwitterAuthenticator authenticateViaTwitterWithOptions:options
                                                        displayProxy:self.displayProxy
                                                             success:^{
                                                                 [self tryToFinishCreatingShare];
                                                             } failure:^(NSError *error) {
                                                                 if ([error isSocializeErrorWithCode:SocializeErrorTwitterCancelledByUser]) {
                                                                     [self failWithError:[NSError defaultSocializeErrorForCode:SocializeErrorShareCancelledByUser]];
                                                                 } else {
                                                                     [self failWithError:error];
                                                                 }
                                                             }];
}

- (void)authenticateViaFacebook {
    SocializeFacebookAuthOptions *options = self.options.facebookAuthOptions;
    if (options == nil) {
        options = [SocializeFacebookAuthOptions options];
    }
    
    // Temporary fix to avoid a double modal transition for v1.5.3 (settings dismiss, composer show)
    options.doNotShowProfile = YES;

    [SocializeFacebookAuthenticator authenticateViaFacebookWithOptions:options
                                                          displayProxy:self.displayProxy
                                                               success:^{
                                                                   [self tryToFinishCreatingShare];
                                                               } failure:^(NSError* error) {
                                                                   if ([error isSocializeErrorWithCode:SocializeErrorFacebookCancelledByUser]) {
                                                                       [self failWithError:[NSError defaultSocializeErrorForCode:SocializeErrorShareCancelledByUser]];
                                                                   } else {
                                                                       [self failWithError:error];
                                                                   }
                                                                   
                                                               }];
}

- (BOOL)createShareBeforeComposition {
    return self.shareObject.medium == SocializeShareMediumSMS || self.shareObject.medium == SocializeShareMediumEmail;
}

- (NSString*)entityURLForThirdParty:(NSString*)thirdParty {
    NSDictionary *propagationInfo = [[self.shareObject propagationInfoResponse] objectForKey:thirdParty];
    NSString *entityURL = [propagationInfo objectForKey:@"entity_url"];
    
    return entityURL;
}

- (NSString*)applicationURLForThirdParty:(NSString*)thirdParty {
    NSDictionary *facebookPropagationInfo = [[self.shareObject propagationInfoResponse] objectForKey:thirdParty];
    NSString *entityURL = [facebookPropagationInfo objectForKey:@"application_url"];
    
    return entityURL;
}

- (void)tryToFinishCreatingShare {
    if (!self.selectedShareMedium) {
        [self showShareActionSheet];
        return;
    }
    
    // Twitter auth required, but we don't yet have it
    if (self.shareObject.medium == SocializeShareMediumTwitter && ![self.socialize isAuthenticatedWithTwitter]) {
        [self authenticateViaTwitter];
        return;
    }
    
    // Facebook auth required, but we don't yet have it
    if (self.shareObject.medium == SocializeShareMediumFacebook && ![self.socialize isAuthenticatedWithFacebook]) {
        [self authenticateViaFacebook];
        return;
    }

    if ([self createShareBeforeComposition]) {
        // We need to create the share with dummy text
        self.shareObject.text = @"n/a";
    } else {
        // Get real text
        if (!self.compositionComplete) {
            [self showCompositionInterface];
            return;
        }
    }
    
    // Create on server
    if (!self.finishedServerCreate) {
        [self.displayProxy startLoading];

        [SocializeShareCreator createShare:self.shareObject
                                   options:nil displayProxy:self.displayProxy
                                   success:^(id<SocializeShare> share) {
                                       self.finishedServerCreate = YES;
                                       self.shareObject = share;
                                       [self tryToFinishCreatingShare];
                                   } failure:^(NSError *error) {
                                       [self failWithError:error];
                                   }];
        return;
    }
    
    if ([self createShareBeforeComposition]) {
        // Composition has no yet been shown
        if (!self.compositionComplete) {
            [self showCompositionInterface];
            return;
        }
    }

    [self succeed];
}

- (void)executeAction {
    [self tryToFinishCreatingShare];
}

- (void)baseViewControllerDidCancel:(SocializeBaseViewController *)baseViewController {
    [self.displayProxy dismissModalViewController:baseViewController];
    [self failWithError:[NSError defaultSocializeErrorForCode:SocializeErrorShareCancelledByUser]];
}

- (void)baseViewControllerDidFinish:(SocializeComposeMessageViewController *)composition {
    [self.displayProxy dismissModalViewController:composition];
    [self.shareObject setText:composition.commentTextView.text];
    self.compositionComplete = YES;
    [self tryToFinishCreatingShare];
}

@end