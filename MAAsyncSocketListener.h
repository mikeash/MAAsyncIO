//
//  MAAsyncSocketListener.h
//  MAAsyncIO
//
//  Created by Michael Ash on 12/8/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class MAAsyncReader;
@class MAAsyncWriter;
@class MAFDSource;

@interface MAAsyncSocketListener : NSObject
{
}

+ (id)listenerWithAddress: (NSData *)address error: (NSError **)error;
+ (id)listenerWith4and6WithPortRange: (NSRange)r tryRandom: (BOOL)tryRandomPorts error: (NSError **)error;

- (int)port;

- (void)setAcceptCallback: (void (^)(MAAsyncReader *reader, MAAsyncWriter *writer, NSData *peerAddress))block;

- (void)invalidate;

@end

@interface MAAsyncSimpleSocketListener : MAAsyncSocketListener
{
    MAFDSource *_source;
    int _fd;
    int _port;
    
    void (^_callback)(MAAsyncReader *reader, MAAsyncWriter *writer, NSData *peerAddress);
}

- (id)initWithAddress: (NSData *)address error: (NSError **)error;

@end

@interface MAAsyncCompoundSocketListener : MAAsyncSocketListener
{
    NSMutableArray *_innerListeners;
}

- (void)addListener: (MAAsyncSocketListener *)listener;

@end
