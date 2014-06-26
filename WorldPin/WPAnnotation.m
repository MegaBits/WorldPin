//
//  WPAnnotation.m
//  WorldPin
//
//  Created by Patrick Perini on 6/17/14.
//  Copyright (c) 2014 MegaBits. All rights reserved.
//

#import "WPAnnotation.h"

@implementation WPAnnotation

@synthesize coordinate;
@synthesize title;
@synthesize subtitle;

- (instancetype)initWithCoordinateString:(NSString *)coordinateString
{
    self = [super init];
    if (!self)
        return nil;
    
    NSArray *coordinateStringPieces = [coordinateString componentsSeparatedByString: @","];
    self.coordinate = CLLocationCoordinate2DMake([[coordinateStringPieces firstObject] doubleValue], [[coordinateStringPieces lastObject] doubleValue]);
    
    return self;
}

- (void)setCoordinate:(CLLocationCoordinate2D)newCoordinate
{
    coordinate = newCoordinate;
}

- (NSString *)description
{
    return [NSString stringWithFormat: @"WPAnnotation {%f, %f}", self.coordinate.latitude, self.coordinate.longitude];
}

@end
