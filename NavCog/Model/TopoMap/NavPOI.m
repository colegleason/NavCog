//
//  NavPOI.m
//  NavCog
//
//  Created by Cole Gleason on 11/13/15.
//  Copyright © 2015 Chengxiong Ruan. All rights reserved.
//

#import "NavPOI.h"
#import "TopoMap.h"
#import <AVFoundation/AVFoundation.h>

@implementation NavPOI

- (NavPOI *)clone {
    NavPOI *poi = [[NavPOI alloc] init];
    poi.name = _name;
    poi.poiID = _poiID;
    poi.poiDescription = _poiDescription;
    poi.location = _location;
    poi.side = _side;
    return poi;
}

@end