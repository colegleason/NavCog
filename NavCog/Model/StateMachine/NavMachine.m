/*******************************************************************************
 * Copyright (c) 2015 Chengxiong Ruan
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

#import "NavMachine.h"
#import "NavNotificationSpeaker.h"

enum NavigationState {NAV_STATE_IDLE, NAV_STATE_WALKING, NAV_STATE_TURNING};

@interface NavMachine ()

@property (strong, nonatomic) CLLocationManager *beaconManager;
@property (strong, nonatomic) CLBeaconRegion *beaconRegion;
@property (strong, nonatomic) CMMotionManager *motionManager;
@property (strong, nonatomic) NavState *initialState;
@property (strong, nonatomic) NavState *currentState;
@property (nonatomic) enum NavigationState navState;
@property (nonatomic) float curOri;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@property (nonatomic) Boolean speechEnabled;
@property (nonatomic) Boolean clickEnabled;
@property (nonatomic) Boolean isStartFromCurrentLocation;
@property (nonatomic) Boolean isNavigationStarted;
@property (strong, nonatomic) NSString *destNodeName;
@property (strong, atomic) NSArray *pathNodes;
@property (strong, nonatomic) TopoMap *topoMap;

@end

@implementation NavMachine

- (instancetype)init
{
    self = [super init];
    if (self) {
        _initialState = nil;
        _currentState = nil;
        _motionManager = [[CMMotionManager alloc] init];
        _motionManager.deviceMotionUpdateInterval = 0.1;
        _navState = NAV_STATE_IDLE;
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
        [_dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"EDT"]];
    }
    return self;
}

// initialize the state machine with a new path of nodes
- (void)initializeWithPathNodes:(NSArray *)pathNodes {
    _initialState = nil;
    _currentState = nil;
    _navState = NAV_STATE_IDLE;
    for (int i = (int)[pathNodes count] - 1; i >= 1; i--) {
        NavNode *node1 = [pathNodes objectAtIndex:i];
        NavNode *node2 = [pathNodes objectAtIndex:i-1];
        NSMutableString *startInfo = [[NSMutableString alloc] init];
        
        NavState *newState = [[NavState alloc] init];
        newState.startNode = node1;
        newState.targetNode = node2;
        
        // if node2 is node1's transit node, then is should be a transition.
        if ([node1 transitEnabledToNode:node2]) {
            newState.type = STATE_TYPE_TRANSITION;
            newState.surroundInfo = [node1 getTransitInfoToNode:node2];
            // targetEdge is used to check if we arrive at next edge or not
            // in our project, we presume that there's no Destination node with transition
            // so we depend on node3's preEdgeInPath to get node2' position
            if (i >= 2) {
                NavNode *node3 = [pathNodes objectAtIndex:i - 2];
                newState.targetEdge = node3.preEdgeInPath;
                [newState.targetEdge initLocalization];
                newState.tx = [node2 getXInEdgeWithID:node3.preEdgeInPath.edgeID];
                newState.ty = [node2 getYInEdgeWithID:node3.preEdgeInPath.edgeID];
            }
            [startInfo appendString:[node1 getInfoComingFromEdgeWithID:node1.preEdgeInPath.edgeID]];
            switch (node1.type) {
                case NODE_TYPE_DOOR_TRANSIT:
                    break;
                case NODE_TYPE_STAIR_TRANSIT:
                    [startInfo appendFormat:NSLocalizedString(@"takeStairsFormat", @"Format string for taking the stairs"), [self getFloorString:node2.floor]];
                    [startInfo appendFormat:NSLocalizedString(@"currentlyOnFormat", @"Format string describes the floor you are currently on"), [self getFloorString:node1.floor]];
                    break;
                case NODE_TYPE_ELEVATOR_TRANSIT:
                    [startInfo appendFormat:NSLocalizedString(@"takeElevatorFormat", @"Format string for taking the elevator"), [self getFloorString:node2.floor]];
                    [startInfo appendFormat:NSLocalizedString(@"currentlyOnFormat", @"Format string describes the floor you are currently on"), [self getFloorString:node1.floor]];
                    break;
                default:
                    break;
            }
        } else {
            newState.type = STATE_TYPE_WALKING;
            newState.walkingEdge = node2.preEdgeInPath;
            [newState.walkingEdge initLocalization];
            newState.surroundInfo = [node2.preEdgeInPath getInfoFromNode:node1];
            newState.isTricky = [node2 isTrickyComingFromEdgeWithID:node2.preEdgeInPath.edgeID];
            newState.trickyInfo = newState.isTricky ? [node2 getTrickyInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID] : nil;
            if (![node2.name isEqualToString:@""]) {
                [startInfo appendFormat:NSLocalizedString(@"feetToNameFormat", @"format string describing the number of feet left to a named location"), node2.preEdgeInPath.len, node2.name];
            } else {
                [startInfo appendFormat:NSLocalizedString(@"feetPauseFormat", @"Use to express a distance in feet with a pause"), node2.preEdgeInPath.len];
            }
            
            float curOri = [node2.preEdgeInPath getOriFromNode:node1];
            newState.ori = curOri;
            newState.sx = [node1 getXInEdgeWithID:node2.preEdgeInPath.edgeID];
            newState.sy = [node1 getYInEdgeWithID:node2.preEdgeInPath.edgeID];
            newState.tx = [node2 getXInEdgeWithID:node2.preEdgeInPath.edgeID];
            newState.ty = [node2 getYInEdgeWithID:node2.preEdgeInPath.edgeID];
            if (i >= 2) {
                NavNode *node3 = [pathNodes objectAtIndex:i - 2];
                [startInfo appendString:NSLocalizedString(@"and", "Simple and used to join two nodes.")];
                if ([node2 transitEnabledToNode:node3]) { // next state is a transition
                    switch (node2.type) {
                        case NODE_TYPE_DOOR_TRANSIT:
                            // for door transition node, we use node information
                            newState.nextActionInfo = [node2 getInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID];
                            [startInfo appendString:[node2 getInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID]];
                            break;
                        case NODE_TYPE_STAIR_TRANSIT:
                            if (node2.floor < node3.floor) {
                                newState.nextActionInfo = NSLocalizedString(@"goUpstairs", @"Short command telling the user to go upstairs");
                                [startInfo appendString:NSLocalizedString(@"goUpstairsStairCase", @"Command telling the user to go up the stairs using the stair case")];
                            } else {
                                newState.nextActionInfo = NSLocalizedString(@"goDownstairs", @"Short command telling the user to go downstairs");
                                [startInfo appendString:NSLocalizedString(@"goDownstairsStairCase", @"Command telling the user to go down the stairs using the stair case")];
                            }
                            break;
                        case NODE_TYPE_ELEVATOR_TRANSIT:
                            if (node2.floor < node3.floor) {
                                newState.nextActionInfo =NSLocalizedString(@"goUpstairsElevator", @"Command telling the user to go upstairs using the elevator");
                                [startInfo appendString:NSLocalizedString(@"takeUpstairsElevator", @"Command telling the user take the elevator upstairs")];
                            } else {
                                newState.nextActionInfo = NSLocalizedString(@"goDownstairsElevator", @"Command telling the user to go downstairs using the elevator");
                                [startInfo appendString:NSLocalizedString(@"takeDownstairsElevator", @"Command telling the user take the elevator downstairs")];
                            }
                            break;
                        default:
                            break;
                    }
                } else { // if next state is normal walking state, then pre-tell the turn
                    float nextOri = [node3.preEdgeInPath getOriFromNode:node2];
                    [startInfo appendString:[self getTurnStringFromOri:curOri toOri:nextOri]];
                    if (![node2 hasTransition] && node2.type != NODE_TYPE_DESTINATION) {
                        newState.arrivedInfo = [node2 getInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID];
                    }
                    newState.nextActionInfo = [self getTurnStringFromOri:curOri toOri:nextOri];
                    if (curOri != nextOri) {
                        newState.approachingInfo = [NSString stringWithFormat:NSLocalizedString(@"approachingToTurnFormat", @"Format string to tell the user they are approaching a turn"), [self getTurnStringFromOri:curOri toOri:nextOri]];
                    }
                }
            } else {
                newState.nextActionInfo = [NSString stringWithFormat:NSLocalizedString(@"destinationFormat", @"Format string for destination alert"), [node2 getInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID]];
                newState.arrivedInfo = [node2 getDestInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID];
                [startInfo appendString:[node2 getInfoComingFromEdgeWithID:node2.preEdgeInPath.edgeID]];
                [startInfo appendString:NSLocalizedString(@"destination", @"Destination alert")];
            }
        }
        
        if (![node1.buildingName isEqualToString:node2.buildingName]) {
            [startInfo appendString:[NSString stringWithFormat:NSLocalizedString(@"enteringFormat", @"Spoken when entering a location"), node2.buildingName]];
        }
        
        newState.stateStartInfo = startInfo;
        if (i == (int)[pathNodes count] - 1) {
            _initialState = newState;
        } else {
            _currentState.nextState = newState;
        }
        _currentState = newState;
    }
    
    _currentState = _initialState;
    // check if we need a initial turning
    
    if (_initialState.type == STATE_TYPE_WALKING) {
        float diff = ABS(_curOri - _initialState.ori);
        
        if (diff < 180) {
            if (diff > 15) {
                _currentState.previousInstruction = [self getTurnStringFromOri:_curOri toOri:_initialState.ori];
                [NavNotificationSpeaker speakWithCustomizedSpeedImmediately:_currentState.previousInstruction];
                _navState = NAV_STATE_TURNING;
            } else {
                _navState = NAV_STATE_WALKING;
            }
        } else {
            if (diff < 345) {
                _currentState.previousInstruction = [self getTurnStringFromOri:_curOri toOri:_initialState.ori];
                [NavNotificationSpeaker speakWithCustomizedSpeedImmediately:_currentState.previousInstruction];
                _navState = NAV_STATE_TURNING;
            } else {
                _navState = NAV_STATE_WALKING;
            }
        }
    }
    
    NavState *state = _initialState;
    while (state != nil) {
        NSLog(@"*****************************************************************");
        NSLog(@"************                                          ***********");
        NSLog(@"*****************************************************************");
        NSLog(@"start info : %@", state.stateStartInfo);
        NSLog(@"approaching info : %@", state.approachingInfo);
        NSLog(@"arrived info : %@", state.arrivedInfo);
        NSLog(@"surounding info : %@", state.surroundInfo);
        NSLog(@"accessibility info : %@", state.trickyInfo);
        state = state.nextState;
    }
}
                                                                
- (NSString *)getFloorString:(int)floor {
    TTTOrdinalNumberFormatter *ordinalNumberFormatter = [[TTTOrdinalNumberFormatter alloc] init];
    [ordinalNumberFormatter setLocale:[NSLocale currentLocale]];
    [ordinalNumberFormatter setGrammaticalGender:TTTOrdinalNumberFormatterMaleGender];
    NSNumber *number = [NSNumber numberWithInteger:floor];
    return [NSString stringWithFormat:NSLocalizedString(@"floorFormat", @"Format string for a floor that takes an ordinal number"), [ordinalNumberFormatter stringFromNumber:number]];
}

- (NSString *)getTurnStringFromOri:(float)curOri toOri:(float)nextOri {
    if (curOri == nextOri || ABS(curOri - nextOri) == 180) {
        return NSLocalizedString(@"keepStraight", @"Instruction to keep straight");
    }
    
    float diff = ABS(curOri - nextOri);
    NSString *slightLeft = NSLocalizedString(@"slightLeft", @"Instruction to turn slightly left");
    NSString *slightRight = NSLocalizedString(@"slightRight", @"Instruction to turn slightly right");
    NSString *turnLeft = NSLocalizedString(@"turnLeft", @"Instruction to turn left");
    NSString *turnRight = NSLocalizedString(@"turnRight", @"Instruction to turn right");
    if (diff < 180) {
        if (diff < 45) {
            return nextOri < curOri ? slightLeft : slightRight;
        } else {
            return nextOri < curOri ? turnLeft : turnRight;
        }
    } else {
        if (diff > 315) {
            return nextOri < curOri ? slightRight : slightLeft;
        } else {
            return nextOri < curOri ? turnRight : turnLeft;
        }
    }
    
    return @"";
}

- (NSString *)getTurnStringWithDegreeFromOri:(float)curOri toOri:(float)nextOri {
    if (curOri == nextOri || ABS(curOri - nextOri) == 180) {
        return NSLocalizedString(@"keepStraight", @"Instruction to keep straight");
    }
    
    int diff = ABS(curOri - nextOri);
    NSString *leftFormat = NSLocalizedString(@"turnLeftDegreeFormat", @"Format string to turn left in degrees");
    NSString *rightFormat = NSLocalizedString(@"turnRightDegreeFormat", @"Format string to turn right in degrees");
    if (diff < 180) {
        return nextOri < curOri ? [NSString stringWithFormat:leftFormat, diff] : [NSString stringWithFormat:rightFormat, diff ];
    } else {
        return nextOri < curOri ? [NSString stringWithFormat:rightFormat, diff ] : [NSString stringWithFormat:leftFormat, diff] ;
    }
    
    return @"";
}

- (void)initializeOrientation {
    [_motionManager stopDeviceMotionUpdates];
    [_motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMDeviceMotion *dm, NSError *error){
        _curOri = - dm.attitude.yaw / M_PI * 180;

        if (_navState == NAV_STATE_TURNING) {
            if (ABS(_curOri - _currentState.ori) <= 10) {
                [NavSoundEffects playSuccessSound];
                _navState = NAV_STATE_WALKING;
            }
        }
    }];
}

- (NSString *)getTimeStamp {
    return [_dateFormatter stringFromDate:[NSDate date]];
}

- (void)startNavigationOnTopoMap:(TopoMap *)topoMap fromNodeWithName:(NSString *)fromNodeName toNodeWithName:(NSString *)toNodeName usingBeaconsWithUUID:(NSString *)uuidstr andMajorID:(CLBeaconMajorValue)majorID withSpeechOn:(Boolean)speechEnabled withClickOn:(Boolean)clickEnabled withFastSpeechOn:(Boolean)fastSpeechEnabled {
    // set speech rate of notification speaker
    [NavNotificationSpeaker setFastSpeechOnAndOff:fastSpeechEnabled];
    
    // set UI type (speech and click sound)
    _speechEnabled = speechEnabled;
    _clickEnabled = clickEnabled;
    
    // search a path
    _topoMap = topoMap;
    _pathNodes = nil;
    if (![fromNodeName isEqualToString:@"Current Location"]) {
        _pathNodes = [_topoMap findShortestPathFromNodeWithName:fromNodeName toNodeWithName:toNodeName];
        [self initializeWithPathNodes:_pathNodes];
        _isStartFromCurrentLocation = false;
        _isNavigationStarted = true;
        [_delegate navigationReadyToGo];
    } else {
        _destNodeName = toNodeName;
        _isStartFromCurrentLocation = true;
        _isNavigationStarted = false;
    }
    
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

- (void)stopNavigation {
    [self stopAudio];
    [_beaconManager stopRangingBeaconsInRegion:_beaconRegion];
    [_topoMap cleanTmpNodeAndEdges];
    _navState = NAV_STATE_IDLE;
    _initialState = nil;
    _currentState = nil;
}

- (void)repeatInstruction {
    if (_currentState != nil) {
        [_currentState repeatPreviousInstruction];
    }
}

- (void)announceSurroundInfo {
    if (_currentState != nil) {
        [_currentState announceSurroundInfo];
    }
}

- (void)announceAccessibilityInfo {
    if (_currentState != nil && _currentState.isTricky) {
        [_currentState announceAccessibilityInfo];
    }
}

- (void)triggerNextState {
    [_beaconManager stopRangingBeaconsInRegion:_beaconRegion];
    _currentState = _currentState.nextState;
    if (_currentState != nil) {
        [_beaconManager startRangingBeaconsInRegion:_beaconRegion];
    } else {
        [_delegate navigationFinished];
        [NavNotificationSpeaker speakWithCustomizedSpeed:NSLocalizedString(@"arrived", @"Spoken when you arrive at a destination")];
        [_topoMap cleanTmpNodeAndEdges];
    }
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region {
    // if we start navigation from current location
    // and the navigation does not start yet
    if (_isStartFromCurrentLocation && !_isNavigationStarted) {
        NavLocation *curLocation = [_topoMap getCurrentLocationOnMapUsingBeacons:beacons];
        if (curLocation.edgeID == nil) {
            return;
        }
        _pathNodes = [_topoMap findShortestPathFromCurrentLocation:curLocation toNodeWithName:_destNodeName];
        [self initializeWithPathNodes:_pathNodes];
        _isNavigationStarted = true;
        [_delegate navigationReadyToGo];
        NSLog(@"***********************************************");
        NSLog(@"layer : %@", curLocation.layerID);
        NSLog(@"edge : %@", curLocation.edgeID);
        NSLog(@"x : %f", curLocation.xInEdge);
        NSLog(@"y : %f", curLocation.yInEdge);
    } else {
        if (_navState == NAV_STATE_WALKING) {
            if ([beacons count] > 0) {
                if ([_currentState checkStateStatusUsingBeacons:beacons withSpeechOn:_speechEnabled withClickOn:_clickEnabled]) {
                    _currentState = _currentState.nextState;
                    if (_currentState == nil) {
                        [_delegate navigationFinished];
                        [NavNotificationSpeaker speakWithCustomizedSpeed:NSLocalizedString(@"arrived", @"Spoken when you arrive at a destination")];
                        [_beaconManager stopRangingBeaconsInRegion:_beaconRegion];
                        [_topoMap cleanTmpNodeAndEdges];
                    } else if (_currentState.type == STATE_TYPE_WALKING) {
                        if (ABS(_curOri - _currentState.ori) > 15) {
                            _currentState.previousInstruction = [self getTurnStringFromOri:_curOri toOri:_currentState.ori];
                            [NavNotificationSpeaker speakWithCustomizedSpeed:_currentState.previousInstruction];
                            _navState = NAV_STATE_TURNING;
                        } else {
                            _navState = NAV_STATE_WALKING;
                        }
                    } else if (_currentState.type == STATE_TYPE_TRANSITION) {
                        _navState = NAV_STATE_WALKING;
                    }
                }
            }
        }
    }
}

- (NSArray *)getPathNodes {
    return _pathNodes;
}

- (void)stopAudio {
    if (_currentState != nil) {
        [_currentState stopAudios];
    }
}

@end
