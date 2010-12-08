//
//  MAAsyncWriter.h
//  MAAsyncIO
//
//  Created by Michael Ash on 12/3/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class MAFDSource;

@interface MAAsyncWriter : NSObject
{
    MAFDSource *_fdSource;
    int _fd;
    
    NSMutableData *_buffer;
    
    void (^_errorHandler)(int);
    void (^_didWriteCallback)(void);
    void (^_eofCallback)(void);
}

// initialization
- (id)initWithFileDescriptor: (int)fd; // sets fd nonblocking, uses MAFDRetain/MAFDRelease to manage it

// setup
- (void)setErrorHandler: (void (^)(int err))block;
- (void)setTargetQueue: (dispatch_queue_t)queue; // default is normal global queue

// notification
- (void)setDidWriteCallback: (void (^)(void))block;
- (void)setEOFCallback: (void (^)(void))block;

// writing
- (void)writeData: (NSData *)data;
- (void)writeCString: (const char *)cstr;

// buffer inspection, can only be called from a callback
- (NSUInteger)bufferSize;

// stopping
- (void)invalidate;

@end
