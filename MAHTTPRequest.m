//
//  MAHTTPRequest.m
//  MAAsyncIO
//
//  Created by Raphael Bartolome on 14.04.11.
//  Copyright 2011 Raphael Bartolome. All rights reserved.
//

#import "MAHTTPRequest.h"


@implementation MAHTTPRequest

- (void)_parseHeader: (NSData *)header
{
    [header retain];
    
    [_request setObject:[NSNumber numberWithInteger:[header length]] forKey:@"Header-Length"];
    NSString *headerAsString = [[NSString alloc] initWithData: header encoding: NSUTF8StringEncoding];
    NSArray *parts = [headerAsString componentsSeparatedByString: @"\n"];
        
    for(NSUInteger i = 0; i < [parts count]; i++)
    {
        if(i == 0)
        {
            NSArray *methodSplit = [[parts objectAtIndex:0] componentsSeparatedByString: @" "];
            [_request setObject:[methodSplit objectAtIndex:0] forKey:@"Method-Type"];
            [_request setObject:[methodSplit objectAtIndex:1] forKey:@"Method"];
        }
        else
        {
            NSArray *partSplit = [[parts objectAtIndex:i] componentsSeparatedByString: @" "];
            NSString *keyPart = [partSplit objectAtIndex:0];
            NSString *key = [keyPart substringToIndex:[keyPart lengthOfBytesUsingEncoding:NSUTF8StringEncoding]-1];
            [_request setObject:[partSplit objectAtIndex:1] forKey:key];            
        }
    }
    
    [headerAsString release];
    [header release];
}

- (id)initWithHeader: (NSData *)header
{
    if ((self = [super init]))
    {
        _request = [[NSMutableDictionary alloc] initWithCapacity:0];
        [self _parseHeader:header];
    }
    
    return self;
}

- (NSDictionary *)request
{
    return _request;
}

- (NSString *)method
{
    return [_request objectForKey:@"Method"]; 
}


- (NSString *)methodType
{
    return [_request objectForKey:@"Method-Type"]; 
}

- (NSInteger)expectedContentLength
{
    if([_request objectForKey:@"Content-Length"])
        return [[_request objectForKey:@"Content-Length"] integerValue];

    return 0;
}

- (void)setContent: (NSData *)data
{
    if(data)
        [_request setObject:data forKey:@"Content"];
}

- (NSData *)content
{
    return [_request objectForKey:@"Content"];
}

- (void)dealloc
{
    [_request release];
    [super dealloc];
}

@end
