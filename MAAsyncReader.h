//
//  MAAsyncReader.h
//  MAAsyncIO
//
//  Created by Michael Ash on 12/1/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import <Cocoa/Cocoa.h>


typedef void (^MAReadCallback)(NSData *data); // nil data means EOF hit before condition met

@class MAFDSource;

@interface MAAsyncReader : NSObject
{
    MAFDSource *_fdSource;
    int _fd;
    
    BOOL _reading;
    BOOL _isEOF;
    
    NSMutableData *_buffer;
    
    void (^_errorHandler)(int);
    
    NSUInteger (^_condition)(NSData *);
    MAReadCallback _readCallback;
}

// initialization
- (id)initWithFileDescriptor: (int)fd; // sets fd nonblocking, uses MAFDRetain/MAFDRelease to manage it

// setup
- (void)setErrorHandler: (void (^)(int err))handlerBlock;
- (void)setTargetQueue: (dispatch_queue_t)queue; // default is normal global queue

// reading
// condition should return byte index to chop data to pass to callback, or
// return NSNotFound for "keep reading"
- (void)readUntilCondition: (NSUInteger (^)(NSData *buffer))condBlock
                  callback: (MAReadCallback)callbackBlock;

- (void)readBytes: (NSUInteger)bytes callback: (MAReadCallback)callbackBlock;
- (void)readUntilData: (NSData *)data callback: (MAReadCallback)callbackBlock;
- (void)readUntilCString: (const char *)cstr callback: (MAReadCallback)callbackBlock;

// stopping
- (void)invalidate;

@end
