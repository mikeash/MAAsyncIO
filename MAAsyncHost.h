//
//  MAAsyncHost.h
//  MAAsyncIO
//
//  Created by Michael Ash on 12/8/10.
//  Copyright 2010 Michael Ash. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MAAsyncHost : NSObject
{
    CFHostRef _cfhost;
    void (^_resolveBlock)(NSArray *addresses, CFStreamError error);
}

+ (id)hostWithName: (NSString *)name;

- (id)initWithName: (NSString *)name;

- (void)resolve: (void (^)(NSArray *addresses, CFStreamError error))block;

@end
