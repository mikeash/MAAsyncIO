//
//  MAAsyncSocketUtils.m
//  MAAsyncIO
//
//  Created by Michael Ash on 12/8/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import "MAAsyncSocketUtils.h"

#import <netinet/in.h>

#import "MAAsyncReader.h"
#import "MAAsyncWriter.h"
#import "MAFDRefcount.h"
#import "MAFDSource.h"


void MAAsyncSocketConnect(NSData *address, int port, void (^block)(MAAsyncReader *reader, MAAsyncWriter *writer, NSError *error))
{
    char localaddr[[address length]];
    [address getBytes: localaddr];
    
    struct sockaddr *sockaddr = (struct sockaddr *)localaddr;
    ((struct sockaddr_in *)sockaddr)->sin_port = htons(port);
    
    int fd = socket(sockaddr->sa_family, SOCK_STREAM, 0);
    if(fd == -1)
    {
        block(nil, nil, [NSError errorWithDomain: NSPOSIXErrorDomain code: errno userInfo: nil]);
    }
    else
    {
        // implicitly sets the socket nonblocking
        MAFDSource *source = [[MAFDSource alloc] initWithFileDescriptor: fd type: DISPATCH_SOURCE_TYPE_WRITE];
        MAFDRelease(fd);
        
        int result = connect(fd, sockaddr, [address length]);
        
        void (^completion)(void) = ^{
            [source suspend];
            
            int err;
            socklen_t len = sizeof(err);
            getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &len);
            if(err)
            {
                block(nil, nil, [NSError errorWithDomain: NSPOSIXErrorDomain code: errno userInfo: nil]);
            }
            else
            {
                MAAsyncReader *reader = [[MAAsyncReader alloc] initWithFileDescriptor: fd];
                MAAsyncWriter *writer = [[MAAsyncWriter alloc] initWithFileDescriptor: fd];
                block(reader, writer, nil);
                [reader release];
                [writer release];
            }
            [source invalidate];
            [source release];
        };
        
        if(result != -1)
        {
            completion();
        }
        else if(errno == EINPROGRESS)
        {
            [source setEventCallback: completion];
            [source resume];
        }
        else
        {
            block(nil, nil, [NSError errorWithDomain: NSPOSIXErrorDomain code: errno userInfo: nil]);
        }
    }
}
