//
//  MAAsyncHTTPServer.h
//  MAAsyncIO
//
//  Created by Michael Ash on 12/9/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class MAAsyncSocketListener;
@class MAAsyncWriter;

@interface MAAsyncHTTPServer : NSObject
{
    MAAsyncSocketListener *_listener;
    void (^_resourceHandler)(NSString *resource, MAAsyncWriter *writer);
}

- (id)initWithPort: (int)port error: (NSError **)error;

- (void)setResourceHandler: (void (^)(NSString *resource, MAAsyncWriter *writer))block;

- (int)port;

@end
