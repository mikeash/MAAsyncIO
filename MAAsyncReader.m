//
//  MAAsyncReader.m
//  MAAsyncIO
//
//  Created by Michael Ash on 12/1/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import "MAAsyncReader.h"


@interface MAAsyncReader ()

- (void)_read;
- (void)_checkCondition;

@end

@implementation MAAsyncReader

- (id)initWithFileDescriptor: (int)fd
{
    if((self = [self init]))
    {
        _queue = dispatch_get_global_queue(0, 0);
        dispatch_retain(_queue);
        
        _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, _queue);
        dispatch_source_set_cancel_handler(_source, ^{ close(fd); });
        
        _fd = fd;
        int flags = fcntl(_fd, F_GETFL, 0);
        fcntl(_fd, F_SETFL, flags | O_NONBLOCK);
        
        __block MAAsyncReader *weakSelf = self;
        dispatch_source_set_event_handler(_source, ^{ [weakSelf _read]; });
        
        _buffer = [[NSMutableData alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [self invalidate];
    
    [_buffer release];
    [_errorHandler release];
    [_condition release];
    [_readCallback release];
    
    [super dealloc];
}

- (void)setErrorHandler: (void (^)(int err))handlerBlock
{
    handlerBlock = [handlerBlock copy];
    [_errorHandler release];
    _errorHandler = handlerBlock;
}

- (void)setQueue: (dispatch_queue_t)queue
{
    NSAssert(!_reading, @"Can't change MAAsyncReader queue while a read is pending");
    
    dispatch_retain(queue);
    dispatch_release(_queue);
    _queue = queue;
    
    dispatch_set_target_queue(_source, _queue);
}

- (void)readUntilCondition: (NSUInteger (^)(NSData *buffer))condBlock
                  callback: (MAReadCallback)callbackBlock
{
    NSAssert(!_reading, @"Can't start a MAAsyncReader read while a read is already pending");
    
    _reading = YES;
    
    _condition = [condBlock copy];
    _readCallback = [callbackBlock copy];
    
    dispatch_async(_queue, ^{
        dispatch_resume(_source);
        [self _checkCondition];
    });
}

- (void)readBytes: (NSUInteger)bytes callback: (MAReadCallback)callbackBlock
{
    [self readUntilCondition: ^(NSData *buffer) { return [buffer length] >= bytes ? bytes : 0; }
                    callback: callbackBlock];
}

- (void)readUntilData: (NSData *)data callback: (MAReadCallback)callbackBlock
{
    [self readUntilCondition: ^(NSData *buffer) {
        NSRange r = [buffer rangeOfData: data options: 0 range: NSMakeRange(0, [buffer length])];
        return r.location == NSNotFound ? 0 : r.location;
    }
                    callback: callbackBlock];
}

- (void)readUntilCString: (const char *)cstr callback: (MAReadCallback)callbackBlock
{
    [self readUntilData: [NSData dataWithBytes: cstr length: strlen(cstr)] callback: callbackBlock];
}

- (void)invalidate
{
    dispatch_sync(_queue, ^{
        dispatch_source_cancel(_source);
    });
}

- (void)_read
{
    NSUInteger howmuch = dispatch_source_get_data(_source);
    howmuch = MAX(howmuch, 128U); // read no less than 128 bytes
    howmuch = MIN(howmuch, 8192U); // read no more than 8kB
    
    NSUInteger oldLength = [_buffer length];
    [_buffer setLength: oldLength + howmuch];
    
    ssize_t result = read(_fd, (char *)[_buffer mutableBytes] + oldLength, howmuch);
    NSUInteger didRead = MAX(result, 0); // if -1 (got an error), that means we read 0 bytes
    [_buffer setLength: oldLength + didRead];
    
    if(result < 0)
    {
        if(errno != EAGAIN && errno != EINTR)
            if(_errorHandler)
                _errorHandler(errno);
    }
    else
    {
        if(result == 0)
            _isEOF = YES;
        [self _checkCondition];
    }
}

- (void)_checkCondition
{
    NSUInteger loc = _condition(_buffer);
    if(loc)
    {
        _reading = NO;
        dispatch_suspend(_source);
        
        NSRange r = NSMakeRange(0, loc);
        NSData *chunk = [_buffer subdataWithRange: r];
        [_buffer replaceBytesInRange: r withBytes: NULL length: 0];
        
        _readCallback(chunk);
    }
    else if(_isEOF)
    {
        _readCallback(nil);
    }
}

@end
