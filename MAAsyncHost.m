//
//  MAAsyncHost.m
//  MAAsyncIO
//
//  Created by Michael Ash on 12/8/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import "MAAsyncHost.h"


@implementation MAAsyncHost

+ (void)_resolutionThread
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSPort *port = [NSPort port];
    [[NSRunLoop currentRunLoop] addPort: port forMode: NSDefaultRunLoopMode];
    [[NSRunLoop currentRunLoop] run];
    [pool release];
}

+ (void)_resolutionGetRunloop: (NSMutableArray *)array
{
    [array addObject: (id)CFRunLoopGetCurrent()];
}

+ (CFRunLoopRef)_resolutionRunloop
{
    static CFRunLoopRef runloop;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        NSThread *thread = [[NSThread alloc] initWithTarget: self selector: @selector(_resolutionThread) object: nil];
        [thread start];
        
        NSMutableArray *runloopArray = [NSMutableArray array];
        [self performSelector: @selector(_resolutionGetRunloop:) onThread: thread withObject: runloopArray waitUntilDone: YES];
        runloop = (CFRunLoopRef)[runloopArray lastObject];
        CFRetain(runloop);
        [thread release];
    });
    return runloop;
}

+ (id)hostWithName: (NSString *)name
{
    return [[[self alloc] initWithName: name] autorelease];
}

- (id)initWithName: (NSString *)name
{
    if((self = [self init]))
    {
        _cfhost = CFHostCreateWithName(NULL, (CFStringRef)name);
    }
    return self;
}

- (void)dealloc
{
    CFRelease(_cfhost);
    [_resolveBlock release];
    
    [super dealloc];
}

static void ResolveCallback(CFHostRef theHost, CFHostInfoType typeInfo, const CFStreamError *error, void *info)
{
    MAAsyncHost *self = info;
    if(error && error->domain)
        self->_resolveBlock(nil, *error);
    else
        self->_resolveBlock((NSArray *)CFHostGetAddressing(self->_cfhost, NULL), (CFStreamError){ 0, 0 });
}

- (void)resolve: (void (^)(NSArray *addresses, CFStreamError error))block
{
    _resolveBlock = [block copy];
    
    CFHostClientContext ctx = { 0, self, CFRetain, CFRelease, NULL };
    CFHostSetClient(_cfhost, ResolveCallback, &ctx);
    
    CFHostScheduleWithRunLoop(_cfhost, [[self class] _resolutionRunloop], kCFRunLoopDefaultMode);
    
    CFStreamError error;
    Boolean success = CFHostStartInfoResolution(_cfhost, kCFHostAddresses, &error);
    
    if(!success)
        block(nil, error);
}

@end
