//
//  MAAsyncHTTPServer.h
//  MAAsyncIO
//
//  Created by Michael Ash on 12/9/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MAHTTPRequest.h"
#import "MAAsyncWriter.h"

@class MAAsyncSocketListener;

extern NSString *const defaultRequestRoute;
extern char *const defaultHTTPHeaderBodySeparator;
typedef void (^MAAsyncHTTPRequestHandler)(MAHTTPRequest *request, MAAsyncWriter *writer);

@interface MAAsyncHTTPServer : NSObject
{
    MAAsyncSocketListener *_listener;
    NSMutableArray *_routes;
    dispatch_queue_t _routesQueue;
}

- (id)initWithPort: (int)port error: (NSError **)error;

- (void)registerDefaultRouteHandler: (MAAsyncHTTPRequestHandler)block;
- (void)registerRoute: (NSString *)route method: (MAHTTPMethod)method handler: (MAAsyncHTTPRequestHandler)block;
- (void)unregisterRoute: (NSString *)route method: (MAHTTPMethod)method;
- (MAAsyncHTTPRequestHandler)registeredRoute:(NSString *)route method: (MAHTTPMethod)method;

- (int)port;

@end
