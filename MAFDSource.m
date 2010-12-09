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
        
#if FD_SOURCE_DEBUG
        _suspendCount = 1;
#endif
        
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
#if FD_SOURCE_DEBUG
    _suspendCount++;
#endif
}

- (void)resume
{
    dispatch_resume(_source);
#if FD_SOURCE_DEBUG
    _suspendCount--;
    assert(_suspendCount >= 0);
#endif
}

- (void)invalidate
{
#if FD_SOURCE_DEBUG
    assert(_suspendCount == 1);
#endif
    
    dispatch_block_t block = ^{
        if(_source)
        {
            dispatch_resume(_source);
            dispatch_source_cancel(_source);
            dispatch_release(_source);
            _source = NULL;
        }
    };
    
    if(dispatch_get_current_queue() != _queue)
        dispatch_sync(_queue, block);
    else
        block();
}

@end
