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
        
        _routes = [[NSMutableDictionary alloc] initWithCapacity:1];
        _routesQueue = dispatch_queue_create([[NSString stringWithFormat:@"com.mikesah.MAAsyncHTTPServer.routesQueue.%i",port] UTF8String], NULL);

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
    dispatch_release(_routesQueue);
    [_listener invalidate];
    [_listener release];
    [_routes release];
    
    [super dealloc];
}


- (void)registerDefaultRouteHandler: (MAAsyncHTTPRequestHandler)block
{
    [self registerRoute: DEFAULT_REQUEST_ROUTE handler: block];
    
    __block MAAsyncHTTPServer *weakSelf = self;
    [_listener setAcceptCallback: ^(MAAsyncReader *reader, MAAsyncWriter *writer, NSData *peerAddress) {
        [weakSelf _gotConnection: reader writer: writer];
    }];
}

- (void)registerRoute:(NSString *)route handler:(MAAsyncHTTPRequestHandler)block
{
    id localBlock = [block copy];

    dispatch_async(_routesQueue, ^{
        [_routes setObject:localBlock forKey:route];
    });
    
    [localBlock release];
}

- (void)unregisterRoute:(NSString *)route
{
    dispatch_async(_routesQueue, ^{
        [_routes removeObjectForKey:route];
    });
}

- (MAAsyncHTTPRequestHandler)registeredRoute:(NSString *)route
{
    __block MAAsyncHTTPRequestHandler resultHandler = nil;
        
     dispatch_sync(_routesQueue, ^{
         if([_routes count] > 0)
         {
             resultHandler = [_routes objectForKey:route];
            
             if(!resultHandler)
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
            }
        }
    
         if(!resultHandler)
             resultHandler = [_routes objectForKey:DEFAULT_REQUEST_ROUTE];
 
         resultHandler = [resultHandler copy];
     });
    
    return [resultHandler autorelease];
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
