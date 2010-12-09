//
//  MAAsyncReader.m
//  MAAsyncIO
//
//  Created by Michael Ash on 12/1/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import "MAAsyncReader.h"

#import "MAFDSource.h"


const NSRange MAKeepReading = { NSNotFound, 0 };

@interface MAAsyncReader ()

- (void)_read;
- (void)_checkCondition;

@end

@implementation MAAsyncReader

- (id)initWithFileDescriptor: (int)fd
{
    if((self = [self init]))
    {
        _fdSource = [[MAFDSource alloc] initWithFileDescriptor: fd type: DISPATCH_SOURCE_TYPE_READ];
        _fd = fd;
        
        __block MAAsyncReader *weakSelf = self;
        [_fdSource setEventCallback: ^{ [weakSelf _read]; }];
        
        _buffer = [[NSMutableData alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_fdSource invalidate];
    [_fdSource release];
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

- (void)setTargetQueue: (dispatch_queue_t)queue
{
    [_fdSource setTargetQueue: queue];
}

- (void)readUntilCondition: (NSRange (^)(NSData *buffer))condBlock
                  callback: (MAReadCallback)callbackBlock
{
    NSAssert(!_reading, @"Can't start a MAAsyncReader read while a read is already pending");
    
    _reading = YES;
    
    _condition = [condBlock copy];
    _readCallback = [callbackBlock copy];
    [self retain]; // make sure we stick around until the read is done
    
    dispatch_async([_fdSource queue], ^{
        [_fdSource resume];
        [self _checkCondition];
    });
}

- (void)readBytes: (NSUInteger)bytes callback: (MAReadCallback)callbackBlock
{
    [self readUntilCondition: ^(NSData *buffer) { return [buffer length] >= bytes ? NSMakeRange(bytes, 0) : MAKeepReading; }
                    callback: callbackBlock];
}

- (void)readUntilData: (NSData *)data callback: (MAReadCallback)callbackBlock
{
    [self readUntilCondition: ^(NSData *buffer) {
        return [buffer rangeOfData: data options: 0 range: NSMakeRange(0, [buffer length])];
    }
                    callback: callbackBlock];
}

- (void)readUntilCString: (const char *)cstr callback: (MAReadCallback)callbackBlock
{
    [self readUntilData: [NSData dataWithBytes: cstr length: strlen(cstr)] callback: callbackBlock];
}

- (void)invalidate
{
    [_fdSource invalidate];
}

- (void)_read
{
    NSUInteger howmuch = [_fdSource bytesAvailable];
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

- (void)_fireReadCallback: (NSData *)data
{
    // a fancy dance so that the callback can set up a new callback without breaking everything
    MAReadCallback localReadCallback = _readCallback;
    _readCallback = nil;
    
    [_condition release];
    _condition = nil;
    
    localReadCallback(data);
    [localReadCallback release];
    
    [self release]; // balance the retain from readUntilCondition:
}

- (void)_checkCondition
{
    if(_condition)
    {
        NSRange r = _condition(_buffer);
        if(r.location != NSNotFound)
        {
            _reading = NO;
            [_fdSource suspend];
            
            NSRange chunkRange = NSMakeRange(0, r.location);
            NSData *chunk = [_buffer subdataWithRange: chunkRange];
            
            NSRange deleteRange = NSMakeRange(0, NSMaxRange(r));
            [_buffer replaceBytesInRange: deleteRange withBytes: NULL length: 0];
            
            [self _fireReadCallback: chunk];
        }
        else if(_isEOF)
        {
            [_fdSource suspend];
            [self _fireReadCallback: nil];
        }
    }
}

@end
