//
//  MAAsyncReader.h
//  MAAsyncIO
//
//  Created by Michael Ash on 12/1/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import <Cocoa/Cocoa.h>


typedef void (^MAReadCallback)(NSData *data, BOOL prematureEOF); // prematureOF = EOF hit before condition met

@class MAFDSource;

@interface MAAsyncReader : NSObject
{
    MAFDSource *_fdSource;
    int _fd;
    
    BOOL _reading;
    BOOL _isEOF;
    
    NSMutableData *_buffer;
    
    void (^_errorHandler)(int);
    
    NSRange (^_condition)(NSData *);
    MAReadCallback _readCallback;
}

// initialization
- (id)initWithFileDescriptor: (int)fd; // sets fd nonblocking, uses MAFDRetain/MAFDRelease to manage it

// setup
- (void)setErrorHandler: (void (^)(int err))handlerBlock;
- (void)setTargetQueue: (dispatch_queue_t)queue; // default is normal global queue

// reading
// condition returns range of delimeter
// everything up to range.location is passed to the callback
// everything within the range is deleted from the buffer
// return NSNotFound in range.location to signal "keep reading"
// or use the MAKeepReading constant
- (void)readUntilCondition: (NSRange (^)(NSData *buffer))condBlock
                  callback: (MAReadCallback)callbackBlock;

- (void)readBytes: (NSUInteger)bytes callback: (MAReadCallback)callbackBlock;
- (void)readUntilData: (NSData *)data callback: (MAReadCallback)callbackBlock;
- (void)readUntilCString: (const char *)cstr callback: (MAReadCallback)callbackBlock;

// stopping
- (void)invalidate;

@end

extern const NSRange MAKeepReading;
