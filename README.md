WorldPin
========

_This README was derived from [our post on Medium](https://medium.com/megabits-lab/aba8796ff48d)_.

Recently, we released [SIOSocket](https://github.com/megabits/siosocket), an open source Objective-C client for [socket.io 1.0](http://socket.io/blog/introducing-socket-io-1-0/). Our last post was all about the motivation for and implementation of SIOSocket, but in this post, we’re building a thing!

## Node.js App ##

The socket.io implementation of the backend server of this app is rather simple. First, let’s start by building our Node’s package.json file.

```json
{
  "name": "WorldPinServer",
  "version": "0.0.0",
  "description": "Server to distributed phone locations to other phones",
  "main": "app.js",
  "author": "myself",
  "dependencies": {
    "socket.io":"1.0.4"
  }
}
```

Once this file is created, run `npm install` and you’ll see your dependency tree builder in action (socket.io will branch to all of its own underlying dependencies, making it easy for us). Next, we’ll fire up our app.js file, which will contain the logic for handling requests. Step one: import the socket.io module.

```js
var io = require('socket.io')(3000);
```

Which brings us to the real meat of our web application. Let’s first write out connection event listener, which will be executed when a client connection occurs.

```js
io.on('connection', function (socket) {
    
});
```

Inside the this function, we’ll add in three major components. First, as soon as a client connects, we’ll emit a __join__ event broadcast, which will include the client’s `id` value.

```js
io.on('connection', function (socket) {
    socket.broadcast.emit('join', socket['id']);
    console.log(socket['id'] + ' has connected!');
});
```

For reference, there are a few different types of communication patterns sockets can use. Pure `emit`s will distribute an event message to every client, including itself. Alternatively, `broadcast.emit`s will distribute an event to every client excluding itself. And for debugging’s sake, we’ve thrown in a console printout when a user connects, as well.

Finally, add two event listeners to handle the various events our clients will be firing off to the server.

```js
socket.on('location', function (data) {
    socket.broadcast.emit('update', (socket['id'] + ':' + data));
});
 
socket.on('disconnect', function () {
    socket.broadcast.emit('disappear', socket['id']);
    console.log(socket['id'] + ' has disconnected!');
});
```

We’ll listen for __location__ events and establish our own custom __disconnect__ event (which occurs after socket.io’s standard __disconnect__ event, as a sort of middleware). When we receive the __location__ event, we’ll broadcast an __update__ event, with the string `"id:data"`, in response. And for the __disconnect__, we will broadcast a __disappear__ event, with the `id` as content. Clients who receive this __disappear__ event will then remove pins labeled with the `id` from the map. For debugging, again, we’ll include a console printout of the socket which has disconnected.

That’s it! With these ~15 lines of code, you’ll be handling real-time communication! To launch, simply trigger `node app.js` in the command line. (Bonus: you can use `DEBUG=socket-io* node app.js` to activate Node’s verbose debugging tools.)

## iOS App ##

Having built our incredibly simple sync app, it’s time to get started on the client side. Start a new iOS Single View Application in Xcode, and drop by the Capabilities tab for the project. Add the Maps capability to include `MapKit.framework` and the necessary entitlements.

![](https://d262ilb51hltx0.cloudfront.net/max/1400/1*F3cz64mcHIWr0AvucE7Fjg.png)

As you might expect, the next step is to create the `MKMapView` in your Storyboard, and hook it up via the necessary `IBOutlet`s. (If this isn’t a familiar process, definitely check out [RW’s Map Kit tutorial](http://www.raywenderlich.com/21365/introduction-to-mapkit-in-ios-6-tutorial).) Once you’ve got a working map view hooked up to your View Controller (and vice versa, as its delegate), we’re ready to start responding to map view’s events. To zoom to the user’s location, use this method:

```objc
- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    // Zoom to user location
    MKMapCamera *camera = [mapView.camera copy];
    camera.altitude = 1; // Zoom in
    camera.centerCoordinate = userLocation.coordinate;
    mapView.camera = camera;
}
```

And to add a new pin whenever an annotation is added, use this method:

```objc
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
```

Now the map can accurately display all WorldPin users!

![](https://d262ilb51hltx0.cloudfront.net/max/1400/1*Qel05T1VYFAWNcgG-KKs7Q.png)

Except, there aren’t any. So we have to get each running instance of WorldPin talking, and to do that, we establish a socketed connection to our Node.js server.  To create an intialize an `SIOSocket` object, we need to call `+[SIOSocket socketWithHost:response:]`, which creates a new socket.io client in a JavaScriptCore context and connects it to the given host.

```objc
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [SIOSocket socketWithHost: @"http://yourHost:3000" response: ^(SIOSocket *socket)
    {
        self.socket = socket;
    }];
}
 
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
```

We’ve also updated our `mapView:didUpdateUserLocation:` to emit a __location__ event whenever our user’s location is updated. The format for this is incredibly simple: the Node server simply receives and broadcasts the `"lat,long"` pair.

Finally, we need to tell our `SIOSocket` to listen for events from the server. The easiest and most obvious events to listen for are __connect__, __join__, and __disappear__.

```objc
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [SIOSocket socketWithHost: @"http://yourHost:3000" response: ^(SIOSocket *socket)
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
        
        [self.socket on: @"disappear" do: ^(id pinID)
        {
            [self.mapView removeAnnotation: self.pins[pinID]];
            [self.pins removeObjectForKey: pinID];
        }];
    }];
}
```

When __connect__ and __join__ events are triggered, we call our own `mapView:didUpdateUserLocation:` method, which fires a __location__ emission, and alerts all other users to our location. When we receive that information, on an __update event__, we should create or update our list of pins.

```objc
[self.socket on: @"update" do: ^(id pinData)
{
    // pinData == @"pinID:lat,long"
    // self.pins == @{@"pinID": <WPAnnotation @ (lat, long)>}
 
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
```

We store pin data as `WPAnnotation` objects, which are simple objects that implement the `MKAnnotation` protocol, and are included in the project’s source. Once our socket can respond to __update__ events, we’re ready to see the location of every WorldPin user!

![](https://d262ilb51hltx0.cloudfront.net/max/1400/1*BRpYrXmTe6dg0hA5H3EwrQ.png)

And, of course, the real benefit of pairing socket.io and MapKit is real-time updates.

![](https://d262ilb51hltx0.cloudfront.net/max/1400/1*DbZSs_6MMCvaL5GAhvFHwA.gif)

And there you have it. The source code for this tutorial is available on our GitHub, and if you have any problems, email dev@megabitsapp.com and we’ll try and help!