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

NSString *const defaultRequestRoute = @"/";
char *const defaultHTTPHeaderBodySeparator = "\r\n\r\n";

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
        
//        _routes = [[NSMutableDictionary alloc] initWithCapacity:1];
        _routes = [[NSMutableArray alloc] initWithCapacity:10];
        for(NSUInteger i = 0; i<10;i++)
            [_routes addObject:[NSMutableDictionary dictionaryWithCapacity:1]];
            
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
    [self registerRoute: defaultRequestRoute method: kMAHTTPNotDefined handler: block];
    
    __block MAAsyncHTTPServer *weakSelf = self;
    [_listener setAcceptCallback: ^(MAAsyncReader *reader, MAAsyncWriter *writer, NSData *peerAddress) {
        [weakSelf _gotConnection: reader writer: writer];
    }];
}

- (void)registerRoute: (NSString *)route method: (MAHTTPMethod)method handler: (MAAsyncHTTPRequestHandler)block
{
    id localBlock = [block copy];

    dispatch_async(_routesQueue, ^{
        NSMutableDictionary *handlerByRoutes = [[_routes objectAtIndex:method] mutableCopy];
        [handlerByRoutes setObject:localBlock forKey:route];
        [_routes replaceObjectAtIndex:method withObject:handlerByRoutes];
        [handlerByRoutes release];
    });
    
    [localBlock release];
}

- (void)unregisterRoute: (NSString *)route method: (MAHTTPMethod)method
{
    dispatch_async(_routesQueue, ^{
        NSMutableDictionary *handlerByRoutes = [[_routes objectAtIndex:method] mutableCopy];
        [handlerByRoutes removeObjectForKey:route];
        [_routes replaceObjectAtIndex:method withObject:handlerByRoutes];
        [handlerByRoutes release];
    });
}

- (MAAsyncHTTPRequestHandler)registeredRoute:(NSString *)route method: (MAHTTPMethod)method
{
    __block MAAsyncHTTPRequestHandler resultHandler = nil;
        
     dispatch_sync(_routesQueue, ^{
         
         if([_routes count] > method)
         {
             NSMutableDictionary *handlerByRoutes = [[_routes objectAtIndex:method] mutableCopy];
             
             if([handlerByRoutes count] > 0)
             {
                 resultHandler = [handlerByRoutes objectForKey:route];
                
                 if(!resultHandler)
                 {
                     NSMutableArray *path = [[route componentsSeparatedByString:@"/"] mutableCopy];
                     NSInteger countIdx = [path count]-1;
                    
                     MAAsyncHTTPRequestHandler resultHandler = nil;
                    
                     while (countIdx > 0) 
                     {
                         [path removeLastObject];
                        
                         NSString *shortPath = [path componentsJoinedByString:@"/"];
                        
                         if([handlerByRoutes objectForKey: shortPath])
                         {
                             resultHandler = [handlerByRoutes objectForKey: shortPath];
                             break;
                         }
                        
                         countIdx--;
                     }
                    
                     [path release];
                }                
             }
             
             [handlerByRoutes release];
         }
    
         if(!resultHandler)
             resultHandler = [[_routes objectAtIndex: kMAHTTPNotDefined] objectForKey: defaultRequestRoute];
 
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

        MAAsyncHTTPRequestHandler handler = [self registeredRoute: [request resource] method: [request method]];
        handler(request, writer);

        [reader invalidate];
    }];
}

- (void)_gotConnection: (MAAsyncReader *)reader writer: (MAAsyncWriter *)writer
{
    [reader readUntilCString: defaultHTTPHeaderBodySeparator callback: ^(NSData *data, BOOL prematureEOF) {
        if(data)
        {            
            MAHTTPRequest *request = [[MAHTTPRequest alloc] initWithHeader: data];
            if([request expectedContentLength] == 0)
            {
                MAAsyncHTTPRequestHandler handler = [self registeredRoute: [request resource] method: [request method]];
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
