//
//  MAAsyncReader.h
//  MAAsyncIO
//
//  Created by Michael Ash on 12/1/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import <Cocoa/Cocoa.h>


typedef void (^MAReadCallback)(NSData *data); // nil data means EOF hit before condition met

@interface MAAsyncReader : NSObject
{
    dispatch_source_t _source;
    dispatch_queue_t _queue;
    int _fd;
    
    BOOL _reading;
    BOOL _isEOF;
    
    NSMutableData *_buffer;
    
    void (^_errorHandler)(int);
    
    NSUInteger (^_condition)(NSData *);
    MAReadCallback _readCallback;
}

// initialization
- (id)initWithFileDescriptor: (int)fd; // takes ownership of fd, sets it nonblocking

// setup
- (void)setErrorHandler: (void (^)(int err))handlerBlock;
- (void)setQueue: (dispatch_queue_t)queue; // default is normal global queue

// reading
// condition should return byte index to chop data to pass to callback, or
// return 0 for "keep reading"
- (void)readUntilCondition: (NSUInteger (^)(NSData *buffer))condBlock
                  callback: (MAReadCallback)callbackBlock;

- (void)readBytes: (NSUInteger)bytes callback: (MAReadCallback)callbackBlock;
- (void)readUntilData: (NSData *)data callback: (MAReadCallback)callbackBlock;
- (void)readUntilCString: (const char *)cstr callback: (MAReadCallback)callbackBlock;

// stopping
- (void)invalidate;

@end
