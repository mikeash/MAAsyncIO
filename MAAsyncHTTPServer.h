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


@interface MAAsyncHTTPServer : NSObject
{
    MAAsyncSocketListener *_listener;
    void (^_requestHandler)(MAHTTPRequest *request, MAAsyncWriter *writer);
}

- (id)initWithPort: (int)port error: (NSError **)error;

- (void)setRequestHandler: (void (^)(MAHTTPRequest *request, MAAsyncWriter *writer))block;

- (int)port;

@end
