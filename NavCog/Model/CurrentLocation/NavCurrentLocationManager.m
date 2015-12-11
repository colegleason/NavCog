//
//  NavCurrentLocationManager.m
//  NavCog
//
//  Created by Cole Gleason on 11/19/15.
//  Copyright © 2015 Chengxiong Ruan. All rights reserved.
//

#import "NavCurrentLocationManager.h"

#define MIN_KNNDIST_THRESHOLD 0.6

@implementation NavCurrentLocationManager;

- (instancetype)initWithMap:(TopoMap *)topoMap usingBeaconsWithUUID:(NSString *)uuidstr andMajorID:(CLBeaconMajorValue)majorID {
    self = [super init];
    if (self) {
        _topoMap = topoMap;
        // set up beacon manager and start ranging
        _beaconManager = [[CLLocationManager alloc] init];
        if([_beaconManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
            [_beaconManager requestAlwaysAuthorization];
        }
        _beaconManager.delegate = self;
        _beaconManager.pausesLocationUpdatesAutomatically = NO;
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidstr];
        _beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid major:majorID identifier:@"cmaccess"];
        [_beaconManager startRangingBeaconsInRegion:_beaconRegion];
    }
    return self;
}

// called whenever a current locaiton is found via ranging
// note that even if location is the same, this will still be called
- (void)updateCurrentLocation:(NavLocation *)location {
    _currentLocation = location;
    _currentEdge = [_topoMap getEdgeFromLayer:_currentLocation.layerID withEdgeID:_currentLocation.edgeID];
    _currentNode = [_currentEdge checkValidEndNodeAtLocation:_currentLocation];
    if (_currentNode != nil) {
        _currentEdge = nil;
    }
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@CURRENT_LOCATION_NOTIFICATION_NAME
                      object:self
                    userInfo:@{@"location":_currentLocation}
     ];
}

// callback for beacon manager when beacons have been found
// if no location has been set yet, this will search the entire
// map for the most probable location. After that it will only
// search the current edge, except if near an edge end node. If
// near a node, then it will try all connecting edges.
- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region {
    NavLocation *location = [[NavLocation alloc] initWithMap:_topoMap];
    if (_currentLocation == nil) {
      // Need an initial location, so search entire map.
        location = [_topoMap getCurrentLocationOnMapUsingBeacons:beacons withInit:YES];
    } else {
        if (_currentNode != nil) {
            // We are on a Node, so need to find all connecting
            // edges and localize on one of them.
            NSArray *neighborEdges = [_currentNode getConnectingEdges];
            location = [_topoMap getLocationInEdges:neighborEdges withBeacons:beacons withKNNThreshold:MIN_KNNDIST_THRESHOLD withInit:NO];
        } else {
            // If not on a node, just localize within the edge we
            // are on.
            struct NavPoint pos = [_currentEdge getCurrentPositionInEdgeUsingBeacons:beacons];

            location.layerID = _currentEdge.parentLayer.zIndex;
            location.edgeID = _currentEdge.edgeID;
            location.xInEdge = pos.x;
            location.yInEdge = pos.y;
        }
    }
    if (location != nil) {
        [self updateCurrentLocation:location];
    }
}

@end;