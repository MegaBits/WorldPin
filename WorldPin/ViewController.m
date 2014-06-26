//
//  ViewController.m
//  WorldPin
//
//  Created by Patrick Perini on 6/17/14.
//  Copyright (c) 2014 MegaBits. All rights reserved.
//

#import "ViewController.h"
#import <MapKit/MapKit.h>
#import <SIOSocket/SIOSocket.h>
#import "WPAnnotation.h"

@interface ViewController () <MKMapViewDelegate>

@property IBOutlet MKMapView *mapView;

@property SIOSocket *socket;
@property BOOL socketIsConnected;

@property NSMutableDictionary *pins;
@property CLLocationManager *locationManager;

@end

@implementation ViewController
            
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.pins = [NSMutableDictionary dictionary];
    [SIOSocket socketWithHost: @"http://10.1.10.16:3000" response: ^(SIOSocket *socket)
    {
        self.socket = socket;
        
        __weak typeof(self) weakSelf = self;
        self.socket.onConnect = ^()
        {
            weakSelf.socketIsConnected = YES;
            [weakSelf mapView: weakSelf.mapView didUpdateUserLocation: weakSelf.mapView.userLocation];
        };
        
        [self.socket on: @"join" do: ^(id pinID)
        {
            [weakSelf mapView: weakSelf.mapView didUpdateUserLocation: weakSelf.mapView.userLocation];
        }];
        
        [self.socket on: @"update" do: ^(id pinData)
        {
            NSArray *dataPieces = [pinData componentsSeparatedByString: @":"];
            NSString *pinID = [dataPieces firstObject];
            
            NSString *pinLocationString = [dataPieces lastObject];
            WPAnnotation *pin = [[WPAnnotation alloc] initWithCoordinateString: pinLocationString];
            
            if ([[self.pins allKeys] containsObject: pinID])
            {
                CLLocationCoordinate2D newCoordinate = pin.coordinate;
                pin = self.pins[pinID];
                
                pin.coordinate = newCoordinate;
                [self.mapView removeAnnotation: pin];
            }
            
            self.pins[pinID] = pin;
            [self.mapView addAnnotation: pin];
        }];
        
        [self.socket on: @"disappear" do: ^(id pinID)
        {
            [self.mapView removeAnnotation: self.pins[pinID]];
            [self.pins removeObjectForKey: pinID];
        }];
    }];
}

#pragma mark - MKMapViewDelegate
- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    // Zoom to user location
    MKMapCamera *camera = [mapView.camera copy];
    camera.altitude = 1; // Zoom in
    camera.centerCoordinate = userLocation.coordinate;
    mapView.camera = camera;
    
    // Broadcast new location
    if (self.socketIsConnected)
    {
        [self.socket emit: @"location",
            [NSString stringWithFormat: @"%f,%f", userLocation.coordinate.latitude, userLocation.coordinate.longitude],
            nil
        ];
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass: [MKUserLocation class]])
        return nil;
    
    MKPinAnnotationView *pinAnnotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier: @"pinAnnotation"];
    [pinAnnotationView setAnnotation: annotation];
    if (!pinAnnotationView)
    {
        pinAnnotationView = [[MKPinAnnotationView alloc] initWithAnnotation: annotation
                                                            reuseIdentifier: @"pinAnnotation"];
    }
    
    pinAnnotationView.pinColor = MKPinAnnotationColorPurple;
    return pinAnnotationView;
}

@end
