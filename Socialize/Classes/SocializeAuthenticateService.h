//
//  SocializeAuthenticateService.h
//  SocializeSDK
//
//  Created by Fawad Haider on 6/13/11.
//  Copyright 2011 Socialize, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SocializeCommonDefinitions.h"
#import "SocializeService.h"
#import "SocializeFBConnect.h"

/**
Socialize authentication service is the authentication engine. It performs anonymously and third party authentication.
 */
@interface SocializeAuthenticateService : SocializeService<SocializeFBSessionDelegate>

@property (nonatomic, readonly) id<SocializeUser>authenticatedUser;

/**@name Anonymous authentication*/
/**
 Authenticate with API key and API secret.
 
 This method is used to perform anonymous authentication. It means that uses could not do any action with his profile.  
 Find information how to get API key and secret on [Socialize.](http://www.getsocialize.com/)
 
 @param apiKey API access key.
 @param apiSecret API access secret.
 @see authenticateWithApiKey:apiSecret:thirdPartyAppId:thirdPartyName:
 @see authenticateWithApiKey:apiSecret:thirdPartyAuthToken:thirdPartyAppId:thirdPartyName:
 */
-(void)authenticateWithApiKey:(NSString*)apiKey  
                    apiSecret:(NSString*)apiSecret;


/**@name Third party authentication*/

- (void)authenticateWithThirdPartyAuthType:(SocializeThirdPartyAuthType)type
                       thirdPartyAuthToken:(NSString*)thirdPartyAuthToken
                 thirdPartyAuthTokenSecret:(NSString*)thirdPartyAuthTokenSecret;

/**
 * This API call is currently unused
 */
- (void)associateWithThirdPartyAuthType:(SocializeThirdPartyAuthType)type
                                  token:(NSString*)token
                            tokenSecret:(NSString*)tokenSecret;

/**@name Other methods*/

/**
 Check if authentication credentials still valid.
 
 @return YES if valid and NO if access token was expired.
 */
+(BOOL)isAuthenticated;

/**
 Remove old authentication information.
 
 If user would like to re-authenticate he has to remove previous authentication information.
 */
-(void)removeSocializeAuthenticationInfo;
/**
 Link Socialize user to an existing Twitter session
 */
- (void)linkToTwitterWithAccessToken:(NSString*)twitterAccessToken accessTokenSecret:(NSString*)twitterAccessTokenSecret;
- (void)linkToFacebookWithAccessToken:(NSString*)facebookAccessToken;

@end
