//
//  MAFDSource.m
//  MAAsyncIO
//
//  Created by Michael Ash on 12/3/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import "MAFDSource.h"

#import "MAFDRefcount.h"


@implementation MAFDSource

- (id)initWithFileDescriptor: (int)fd type: (dispatch_source_type_t)type
{
    if((self = [self init]))
    {
        _queue = dispatch_queue_create("com.mikeash.MAAsyncReader", NULL);
        
        _fd = MAFDRetain(fd);
        
        _source = dispatch_source_create(type, fd, 0, _queue);
        dispatch_source_set_cancel_handler(_source, ^{ MAFDRelease(fd); });
        
        int flags = fcntl(_fd, F_GETFL, 0);
        fcntl(_fd, F_SETFL, flags | O_NONBLOCK);
    }
    return self;
}

- (void)dealloc
{
    [self invalidate];
    dispatch_release(_queue);
    
    [super dealloc];
}

- (void)setEventCallback: (dispatch_block_t)block
{
    dispatch_source_set_event_handler(_source, block);
}

- (void)setTargetQueue: (dispatch_queue_t)queue
{
    dispatch_set_target_queue(_queue, queue);
}

- (dispatch_queue_t)queue
{
    return _queue;
}

- (NSUInteger)bytesAvailable
{
    return dispatch_source_get_data(_source);
}

- (void)suspend
{
    dispatch_suspend(_source);
}

- (void)resume
{
    dispatch_resume(_source);
}

- (void)invalidate
{
    dispatch_sync(_queue, ^{
        dispatch_source_cancel(_source);
    });
}

@end
