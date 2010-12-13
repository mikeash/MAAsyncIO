//
//  MAAsyncHost.h
//  MAAsyncIO
//
//  Created by Michael Ash on 12/8/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import <Cocoa/Cocoa.h>


// code will be the domain of the CFStreamError
// error code will be in userinfo "cfcode"
extern NSString * const MACFStreamNSErrorDomain;

@class MAAsyncReader;
@class MAAsyncWriter;

@interface MAAsyncHost : NSObject
{
    CFHostRef _cfhost;
    dispatch_queue_t _queue;
    BOOL _resolving;
    NSArray *_addresses;
    NSMutableArray *_resolveBlocks;
}

+ (id)hostWithName: (NSString *)name;

- (id)initWithName: (NSString *)name;

- (void)resolve: (void (^)(NSArray *addresses, CFStreamError error))block;

// this will automatically resolve the host and then try to connect to all of the resolved addresses
// in sequence until one works
// errors will be in the MACFStreamNSErrorDomain if resolution fails
- (void)connectToPort: (int)port callback: (void (^)(MAAsyncReader *reader, MAAsyncWriter *writer, NSError *error))block;

@end
