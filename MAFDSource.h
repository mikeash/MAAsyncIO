//
//  MAFDSource.h
//  MAAsyncIO
//
//  Created by Michael Ash on 12/3/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import <Cocoa/Cocoa.h>


#define FD_SOURCE_DEBUG 1

@interface MAFDSource : NSObject
{
    dispatch_source_t _source;
    dispatch_queue_t _queue;
    int _fd;
    
#if FD_SOURCE_DEBUG
    int _suspendCount;
#endif
}

- (id)initWithFileDescriptor: (int)fd type: (dispatch_source_type_t)type; // takes ownership of fd

- (void)setEventCallback: (dispatch_block_t)block;
- (void)setTargetQueue: (dispatch_queue_t)queue;
- (dispatch_queue_t)queue;

- (NSUInteger)bytesAvailable;

- (void)suspend;
- (void)resume;
- (void)invalidate;

@end
