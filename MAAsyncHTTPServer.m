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
    [_requestHandler release];
    [super dealloc];
}

- (void)setRequestHandler: (void (^)(MAHTTPRequest *request, MAAsyncWriter *writer))block
{
    _requestHandler = [block copy];
    __block MAAsyncHTTPServer *weakSelf = self;
    [_listener setAcceptCallback: ^(MAAsyncReader *reader, MAAsyncWriter *writer, NSData *peerAddress) {
        [weakSelf _gotConnection: reader writer: writer];
    }];
}

- (int)port
{
    return [_listener port];
}

- (void)_readRequestContent: (MAAsyncReader *)reader writer: (MAAsyncWriter *)writer request: (MAHTTPRequest *)request
{
    [reader readBytes:[request expectedContentLength] callback: ^(NSData *data, BOOL prematureEOF) {
        [request setContent:data];
        _requestHandler(request, writer);            
        [reader invalidate];
    }];
}

- (void)_gotConnection: (MAAsyncReader *)reader writer: (MAAsyncWriter *)writer
{
    [reader readUntilCString: "\r\n\r\n" callback: ^(NSData *data, BOOL prematureEOF) {
        if(data)
        {            
            MAHTTPRequest *request = [[MAHTTPRequest alloc] initWithHeader:data];
            if([request expectedContentLength] == 0)
            {
                _requestHandler(request, writer);
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
