//
//  NavPOI.h
//  NavCog
//
//  Created by Cole Gleason on 11/13/15.
//  Copyright © 2015 Chengxiong Ruan. All rights reserved.
//

#ifndef NavPOI_h
#define NavPOI_h

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "KDTreeLocalization.h"

@class NavLocation;

enum POISide {POI_LEFT, POI_RIGHT};

@interface NavPOI : NSObject

@property (nonatomic) NSString *poiID;
@property (nonatomic) NSString *name;
@property (nonatomic) NSString *poiDescription;
@property (nonatomic) NavLocation *location;
@property (nonatomic) enum POISide side;

- (NavPOI *)clone;

@end

#endif /* NavPOI_h */
