//
//  MAAsyncSocketListener.m
//  MAAsyncIO
//
//  Created by Michael Ash on 12/8/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import "MAAsyncSocketListener.h"

#import <mach/mach_time.h>
#import <netinet/in.h>
#import <netinet6/in6.h>

#import "MAAsyncReader.h"
#import "MAAsyncWriter.h"
#import "MAFDRefcount.h"
#import "MAFDSource.h"


@implementation MAAsyncSocketListener

+ (id)listenerWithAddress: (NSData *)address error: (NSError **)error
{
    return [[[MAAsyncSimpleSocketListener alloc] initWithAddress: address error: error] autorelease];
}

+ (id)listenerWith4and6WithPortRange: (NSRange)r tryRandom: (BOOL)tryRandomPorts error: (NSError **)error
{
    NSError *localError = nil;
    if(!error)
        error = &localError;
    
    NSMutableData *addr4data = [NSMutableData dataWithLength: sizeof(struct sockaddr_in)];
    NSMutableData *addr6data = [NSMutableData dataWithLength: sizeof(struct sockaddr_in6)];
    struct sockaddr_in *addr4 = [addr4data mutableBytes];
    struct sockaddr_in6 *addr6 = [addr6data mutableBytes];
    
    addr4->sin_len = sizeof(*addr4);
    addr6->sin6_len = sizeof(*addr6);
    
    addr4->sin_family = AF_INET;
    addr6->sin6_family = AF_INET6;
    
    addr4->sin_addr.s_addr = INADDR_ANY;
    addr6->sin6_addr = in6addr_any;
    
    MAAsyncCompoundSocketListener *listener = nil;
    
    for(NSUInteger i = 0; tryRandomPorts || i < r.length; i++)
    {
        int port = (i < r.length
                    ? i + r.location
                    : mach_absolute_time()) % 65536;
        
        // 0 has special meaning, which screws up the rest of the code
        if(port == 0)
            continue;
        
        addr4->sin_port = htons(port);
        addr6->sin6_port = htons(port);
        
        MAAsyncSimpleSocketListener *listener4 = [[MAAsyncSimpleSocketListener alloc] initWithAddress: addr4data error: error];
        if(listener4)
        {
            MAAsyncSimpleSocketListener *listener6 = [[MAAsyncSimpleSocketListener alloc] initWithAddress: addr6data error: error];
            if(listener6)
            {
                listener = [[MAAsyncCompoundSocketListener alloc] init];
                [listener addListener: listener4];
                [listener addListener: listener6];
                [listener autorelease];
                break;
            }
            // everything from here is an error case
            [listener4 release];
        }
        
        // if it's NOT EADDRINUSE or EACCES then report it
        if(![[*error domain] isEqual: NSPOSIXErrorDomain] ||
           ([*error code] != EADDRINUSE && [*error code] != EACCES))
            break;
    }
    
    return listener;
}

- (int)port
{
    [self doesNotRecognizeSelector: _cmd];
    return 0;
}

- (void)setAcceptCallback: (void (^)(MAAsyncReader *reader, MAAsyncWriter *writer, NSData *peerAddress))block
{
    [self doesNotRecognizeSelector: _cmd];
}

- (void)invalidate
{
    [self doesNotRecognizeSelector: _cmd];
}

@end

@interface MAAsyncSimpleSocketListener ()

- (void)_accept;

@end

@implementation MAAsyncSimpleSocketListener

- (id)initWithAddress: (NSData *)address error: (NSError **)error
{
    if((self = [self init]))
    {
        const struct sockaddr_in *addrPtr = [address bytes];
        
        int fd = socket(addrPtr->sin_family, SOCK_STREAM, 0);
        if(fd == -1)
        {
            if(error)
                *error = [NSError errorWithDomain: NSPOSIXErrorDomain code: errno userInfo: nil];
            [self release];
            return nil;
        }
        
        int yes = 1;
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
        
        int result = bind(fd, [address bytes], [address length]);
        if(result == -1)
        {
            if(error)
                *error = [NSError errorWithDomain: NSPOSIXErrorDomain code: errno userInfo: nil];
            close(fd);
            [self release];
            return nil;
        }
        
        result = listen(fd, SOMAXCONN);
        if(result == -1)
        {
            if(error)
                *error = [NSError errorWithDomain: NSPOSIXErrorDomain code: errno userInfo: nil];
            close(fd);
            [self release];
            return nil;
        }
        
        _source = [[MAFDSource alloc] initWithFileDescriptor: fd type: DISPATCH_SOURCE_TYPE_READ];
        MAFDRelease(fd);
        _fd = fd;
        _port = ntohs(addrPtr->sin_port);
        
        __block MAAsyncSimpleSocketListener *weakSelf = self;
        [_source setEventCallback: ^{ [weakSelf _accept]; }];
    }
    return self;
}

- (void)dealloc
{
    [self invalidate];
    
    [super dealloc];
}

- (int)port
{
    return _port;
}

- (void)setAcceptCallback: (void (^)(MAAsyncReader *reader, MAAsyncWriter *writer, NSData *peerAddress))block
{
    if(!_source && !_callback && !block)
        return;
    
    dispatch_async([_source queue], ^{
        if(!_callback && block)
            [_source resume];
        if(_callback && !block)
            [_source suspend];
        
        id copiedBlock = [block copy];
        [_callback release];
        _callback = copiedBlock;
    });
}

- (void)invalidate
{
    [self setAcceptCallback: nil];
    [_source invalidate];
}

- (void)_accept
{
    NSMutableData *peerAddress = [NSMutableData dataWithLength: 256];
    socklen_t peerLen = [peerAddress length];
    int newfd = accept(_fd, [peerAddress mutableBytes], &peerLen);
    if(newfd == -1)
    {
        NSLog(@"%s error %d (%s)", __func__, errno, strerror(errno));
        return;
    }
    
    [peerAddress setLength: peerLen];
    
    MAAsyncReader *reader = [[MAAsyncReader alloc] initWithFileDescriptor: newfd];
    MAAsyncWriter *writer = [[MAAsyncWriter alloc] initWithFileDescriptor: newfd];
    MAFDRelease(newfd);
    
    _callback(reader, writer, peerAddress);
    [reader release];
    [writer release];
}

@end

@implementation MAAsyncCompoundSocketListener

- (id)init
{
    if((self = [super init]))
    {
        _innerListeners = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [self invalidate];
    [_innerListeners release];
    
    [super dealloc];
}

- (void)addListener: (MAAsyncSocketListener *)listener
{
    [_innerListeners addObject: listener];
}

- (int)port
{
    return [_innerListeners count] ? [(MAAsyncSocketListener *)[_innerListeners lastObject] port] : -1;
}

- (void)setAcceptCallback: (void (^)(MAAsyncReader *reader, MAAsyncWriter *writer, NSData *peerAddress))block
{
    for(MAAsyncSocketListener *listener in _innerListeners)
        [listener setAcceptCallback: block];
}

- (void)invalidate
{
    for(MAAsyncSocketListener *listener in _innerListeners)
        [listener invalidate];
}

@end

