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
#import "MAAsyncWriter.h"


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
    [_resourceHandler release];
    [super dealloc];
}

- (void)setResourceHandler: (void (^)(NSString *resource, MAAsyncWriter *writer))block
{
    _resourceHandler = [block copy];
    __block MAAsyncHTTPServer *weakSelf = self;
    [_listener setAcceptCallback: ^(MAAsyncReader *reader, MAAsyncWriter *writer, NSData *peerAddress) {
        [weakSelf _gotConnection: reader writer: writer];
    }];
}

- (int)port
{
    return [_listener port];
}

- (void)_readRequestLines: (MAAsyncReader *)reader writer: (MAAsyncWriter *)writer resource: (NSString *)resource
{
    [reader readUntilCString: "\r\n" callback: ^(NSData *data) {
        if([data length])
        {
            NSString *s = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
            [s release];
            [self _readRequestLines: reader writer: writer resource: resource];
        }
        else
        {
            _resourceHandler(resource, writer);
            
            [reader invalidate];
        }
    }];
}

- (void)_gotConnection: (MAAsyncReader *)reader writer: (MAAsyncWriter *)writer
{
    [reader readUntilCString: "\r\n" callback: ^(NSData *data) {
        if(data)
        {
            NSString *s = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
            NSArray *parts = [s componentsSeparatedByString: @" "];
            if([parts count] >= 2)
            {
                NSString *resource = [parts objectAtIndex: 1];
                [self _readRequestLines: reader writer: writer resource: resource];
            }
            [s release];
        }
    }];
}

@end
