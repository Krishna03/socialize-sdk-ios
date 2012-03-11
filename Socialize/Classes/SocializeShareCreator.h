//
//  SocializeShareCreator.h
//  SocializeSDK
//
//  Created by Nathaniel Griswold on 3/9/12.
//  Copyright (c) 2012 Socialize, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SocializeActivityCreator.h"
#import "SocializeShare.h"

@interface SocializeShareCreator : SocializeActivityCreator
@property (nonatomic, readonly) id<SocializeShare> share;
@end