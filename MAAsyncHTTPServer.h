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

#define DEFAULT_REQUEST_ROUTE @"/"
#define HTTP_HEADER_BODY_SEPARATOR "\r\n\r\n"

typedef void (^MAAsyncHTTPRequestHandler)(MAHTTPRequest *request, MAAsyncWriter *writer);

@interface MAAsyncHTTPServer : NSObject
{
    MAAsyncSocketListener *_listener;
    NSDictionary *_routes;
}

- (id)initWithPort: (int)port error: (NSError **)error;

- (void)registerDefaultRouteHandler: (MAAsyncHTTPRequestHandler)block;
- (void)registerRoute:(NSString *)route handler:(MAAsyncHTTPRequestHandler)block;

- (void)unregisterRoute: (NSString *)route;

- (int)port;

@end
