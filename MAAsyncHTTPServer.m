//
//  MAAsyncHTTPServer.m
//  MAAsyncIO
//
//  Created by Michael Ash on 12/9/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import "MAAsyncHTTPServer.h"

#import "MAAsyncReader.h"
#import "MAAsyncSocketListener.h"

@interface MAAsyncHTTPServer ()

- (void)_gotConnection: (MAAsyncReader *)reader writer: (MAAsyncWriter *)writer;

@end

@implementation MAAsyncHTTPServer

- (id)initWithPort: (int)port error: (NSError **)error
{
    if((self = [self init]))
    {
        NSRange r;
        if(port > 0)
            r = NSMakeRange(port, 1);
        else
            r = NSMakeRange(0, 0);
        
        _listener = [[MAAsyncSocketListener listenerWith4and6WithPortRange: r tryRandom: port <= 0 error: error] retain];
        if(!_listener)
        {
            [self release];
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    [_listener invalidate];
    [_listener release];
    [_routes release];
    
    [super dealloc];
}

- (void)start
{
    __block MAAsyncHTTPServer *weakSelf = self;
    [_listener setAcceptCallback: ^(MAAsyncReader *reader, MAAsyncWriter *writer, NSData *peerAddress) {
        [weakSelf _gotConnection: reader writer: writer];
    }];
}

- (void)stop
{
    [_listener setAcceptCallback:nil];
}

- (void)setRoutes: (NSDictionary *)dict
{
    [_routes autorelease];
    _routes = [dict copy];
}

- (void)registerDefaultRouteHandler: (MAAsyncHTTPRequestHandler)block
{
    [self registerRoute: DEFAULT_REQUEST_ROUTE handler: block];
    [self start];
}

- (void)registerRoute:(NSString *)route handler:(MAAsyncHTTPRequestHandler)block
{
    id localBlock = [block copy];
    
    NSMutableDictionary *localRoutes = [NSMutableDictionary dictionaryWithDictionary:_routes];
    [localRoutes setObject:localBlock forKey:route];
    
    [localBlock release];
    [self setRoutes:localRoutes];
}

- (void)unregisterRoute:(NSString *)route
{
    NSMutableDictionary *localRoutes = [NSMutableDictionary dictionaryWithDictionary:_routes];

    [localRoutes removeObjectForKey:route];
    
    [self setRoutes:localRoutes];
}

- (MAAsyncHTTPRequestHandler)registeredRoute:(NSString *)route
{
    if([_routes count] > 0)
    {
        MAAsyncHTTPRequestHandler handler = [_routes objectForKey:route];
        
        if(handler)
        {
            return handler;
        }
        else
        {
            NSMutableArray *path = [[route componentsSeparatedByString:@"/"] mutableCopy];
            NSInteger countIdx = [path count]-1;
            
            MAAsyncHTTPRequestHandler resultHandler = nil;
            
            while (countIdx > 0) 
            {
                [path removeLastObject];
                
                NSString *shortPath = [path componentsJoinedByString:@"/"];
                
                if([_routes objectForKey:shortPath])
                {
                    resultHandler = [_routes objectForKey:shortPath];
                    break;
                }
                
                countIdx--;
            }
            
            [path release];
            return resultHandler;
        }
    }
    
    return [_routes objectForKey:DEFAULT_REQUEST_ROUTE];
}

- (int)port
{
    return [_listener port];
}

- (void)_readRequestContent: (MAAsyncReader *)reader writer: (MAAsyncWriter *)writer request: (MAHTTPRequest *)request
{
    [reader readBytes:[request expectedContentLength] callback: ^(NSData *data, BOOL prematureEOF) {
        [request setContent:data];

        MAAsyncHTTPRequestHandler handler = [self registeredRoute:[request resource]];
        handler(request, writer);

        [reader invalidate];
    }];
}

- (void)_gotConnection: (MAAsyncReader *)reader writer: (MAAsyncWriter *)writer
{
    [reader readUntilCString: HTTP_HEADER_BODY_SEPARATOR callback: ^(NSData *data, BOOL prematureEOF) {
        if(data)
        {            
            MAHTTPRequest *request = [[MAHTTPRequest alloc] initWithHeader:data];
            if([request expectedContentLength] == 0)
            {
                MAAsyncHTTPRequestHandler handler = [self registeredRoute:[request resource]];
                handler(request, writer); 

                [reader invalidate];
            }
            else
            {
                [self _readRequestContent:reader writer:writer request:request];
            }
            
            [request release];
        }
    }];
}

@end
