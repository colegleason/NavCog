//
//  CurrentLocationEngine.m
//  NavCog
//
//  Created by Cole Gleason on 11/19/15.
//  Copyright © 2015 Chengxiong Ruan. All rights reserved.
//

#import "CurrentLocationEngine.h"

#define MIN_KNNDIST_THRESHOLD 0.6

@implementation CurrentLocationEngine;

- (instancetype)initWithMap:(TopoMap *)topoMap usingBeaconsWithUUID:(NSString *)uuidstr andMajorID:(CLBeaconMajorValue)majorID {
    self = [super init];
    if (self) {
        _topoMap = topoMap;
        // start navigation
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

- (void)updateCurrentLocation:(NavLocation *)location {
    _currentLocation = location;
    _currentEdge = [_topoMap getEdgeFromLayer:_currentLocation.layerID withEdgeID:_currentLocation.edgeID];
    _currentNode = [_currentEdge checkValidEndNodeAtLocation:_currentLocation];
    if (_currentNode != nil) {
        _currentEdge = nil;
    }
    [[NSNotificationCenter defaultCenter]   postNotificationName:@"CurrentLocationNotification"
                                                          object:self userInfo:@{@"location":_currentLocation}];
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region {
    NavLocation *location = [[NavLocation alloc] init];
    if (_currentLocation == nil) {
      // Need an initial location, so search entire map.
      location = [_topoMap getCurrentLocationOnMapUsingBeacons:beacons];
    } else {
        if (_currentNode != nil) {
            // We are on a Node, so need to find all connecting
            // edges and localize on one of them.
            NSArray *neighborEdges = [self getNeighborEdgesForNode:_currentNode];
            location = [_topoMap getCurrentLocationInEdges:neighborEdges withBeacons:beacons withKnnThreshold:MIN_KNNDIST_THRESHOLD];
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

- (NSArray *) getNeighborEdgesForNode:(NavNode *)node {
    NSMutableArray *edges = [[NSMutableArray alloc] init];
    for (NavNeighbor *neighbor in node.neighbors) {
        [edges addObject:neighbor.edge];
    }
    return edges;
}

@end;