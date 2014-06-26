//
//  WPAnnotation.h
//  WorldPin
//
//  Created by Patrick Perini on 6/17/14.
//  Copyright (c) 2014 MegaBits. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface WPAnnotation : NSObject <MKAnnotation>

- (instancetype)initWithCoordinateString:(NSString *)coordinateString;

@end
