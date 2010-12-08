//
//  MAAsyncSocketUtils.h
//  MAAsyncIO
//
//  Created by Michael Ash on 12/8/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class MAAsyncReader;
@class MAAsyncWriter;

void MAAsyncSocketConnect(NSData *address, int port, void (^block)(MAAsyncReader *reader, MAAsyncWriter *writer, NSError *error));
