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
    
    _headerLength = [header length];

    NSString *headerAsString = [[NSString alloc] initWithData: header encoding: NSUTF8StringEncoding];
    NSArray *parts = [headerAsString componentsSeparatedByString: @"\n"];
        
    for(NSUInteger i = 0; i < [parts count]; i++)
    {
        if(i == 0)
        {
            NSArray *methodSplit = [[parts objectAtIndex:0] componentsSeparatedByString: @" "];
            _methodType = [[NSString alloc] initWithString:[methodSplit objectAtIndex:0]];
            _method = [[NSString alloc] initWithString:[methodSplit objectAtIndex:1]];
        }
        else
        {
            NSArray *partSplit = [[parts objectAtIndex:i] componentsSeparatedByString: @" "];
            NSString *keyPart = [partSplit objectAtIndex:0];
            NSString *key = [keyPart substringToIndex:[keyPart lengthOfBytesUsingEncoding:NSUTF8StringEncoding]-1];
            [_header setObject:[partSplit objectAtIndex:1] forKey:key];            
        }
    }
    
    [headerAsString release];
    [header release];
}

- (id)initWithHeader: (NSData *)header
{
    if ((self = [super init]))
    {
        _header = [[NSMutableDictionary alloc] initWithCapacity:0];
        [self _parseHeader:header];
    }
    
    return self;
}

- (NSDictionary *)header
{
    return _header;
}

- (NSInteger)headerLength
{
    return _headerLength;
}

- (NSString *)method
{
    return _method; 
}


- (NSString *)methodType
{
    return _methodType; 
}

- (NSInteger)expectedContentLength
{
    if([_header objectForKey:@"Content-Length"])
        return [[_header objectForKey:@"Content-Length"] integerValue];

    return 0;
}

- (void)setContent: (NSData *)data
{
    [_content release];
    _content = [data copy];
}

- (NSData *)content
{
    return _content;
}

- (void)dealloc
{
    [_methodType release];
    [_method release];
    [_content release];
    [_header release];
    [super dealloc];
}

@end
