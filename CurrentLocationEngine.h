//
//  CurrentLocationEngine.h
//  NavCog
//
//  Created by Cole Gleason on 11/19/15.
//  Copyright © 2015 Chengxiong Ruan. All rights reserved.
//

#ifndef CurrentLocationEngine_h
#define CurrentLocationEngine_h

#import <Foundation/Foundation.h>
#import "TopoMap.h"
#import <CoreLocation/CoreLocation.h>
#import "KDTreeLocalization.h"

// This will be used for exploration. It will first find an edge
// you are in, then create a localization KDTree on that edge.
// It will provide notification updates, and other services may
// subscribe to those.
// How do we handle transitions to other edges?

@class NavLocation;

@interface CurrentLocationEngine : NSObject

@property (strong, nonatomic) CLLocationManager *beaconManager;
@property (strong, nonatomic) CLBeaconRegion *beaconRegion;
@property (nonatomic) TopoMap *topoMap;
@property (nonatomic) NavLocation *currentLocation;
@property (nonatomic) NavEdge *currentEdge;
@property (nonatomic) NavNode *currentNode;

@end;

#endif /* CurrentLocationEngine_h */
