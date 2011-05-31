//
//  MAHTTPRequest.m
//  MAAsyncIO
//
//  Created by Raphael Bartolome on 14.04.11.
//  Copyright 2011 Raphael Bartolome. All rights reserved.
//

#import "MAHTTPRequest.h"


/*
 kMAHTTPGetMethod,
 kMAHTTPPostMethod,
 kMAHTTPPutMethod,
 kMAHTTPHeadMethod,
 kMAHTTPDeleteMethod,
 kMAHTTPTraceMethod,
 kMAHTTPOptionsMethod,
 kMAHTTPConnectMethod,
 kMAHTTPPathMethod,
 kMAHTTPNotDefined,
 */
@implementation MAHTTPRequest

- (void)setMethod: (NSString *)method
{
    [_method release];
    _method = [method copy];
}

- (NSString *)_decodeURL: (NSString *)string
{
    [string retain];
    NSString *result = (NSString *)CFURLCreateStringByReplacingPercentEscapes(kCFAllocatorDefault,
                                                                              (CFStringRef)string,
                                                                              CFSTR(""));
    
    if(result == NULL)
    {
        return [string autorelease];
    }
    else
    {
        [string release];
        return [result autorelease];
    }
}

- (void)_parseFormValues: (NSString *)kvps
{
    [kvps retain];
    NSArray *splitKVP = [kvps componentsSeparatedByString: @"&"];
    
    for(NSUInteger i = 0; i < [splitKVP count]; i++)
    {
        NSString *kvp = [splitKVP objectAtIndex:i];
        NSScanner *scanner = [[NSScanner alloc] initWithString:kvp];
        
        NSString *key = NULL;
        NSString *value = NULL;
        if([scanner scanUpToString:@"=" intoString:&key])
        {	
            value = [kvp substringFromIndex:[scanner scanLocation]+1];            
        }
        
        NSString *decodedKey = [[self _decodeURL:key] retain];
        NSString *decodedValue = [[self _decodeURL:value] retain];
        
        [_formValues setObject:decodedValue forKey:decodedKey];  
        
        [decodedKey release];
        [decodedValue release];
        
        [scanner release];
    }    
    
    [kvps release];
}

- (void)_parseResource: (NSString *)resource
{
    [resource retain];

    if([self method] != kMAHTTPPostMethod)
    {
        NSArray *splitMethodValues = [resource componentsSeparatedByString: @"?"];
        
        if([splitMethodValues count] >= 1)
        {
            _resource = [[splitMethodValues objectAtIndex:0] copy];
            
            if([splitMethodValues count] > 1)
            {
                [self _parseFormValues:[splitMethodValues objectAtIndex:1]];
            }
        }
    }
    else
    {
        _resource = [resource copy];
    }
    
    [resource release];
}

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
            [self setMethod:[methodSplit objectAtIndex:0]];
            [self _parseResource:[methodSplit objectAtIndex:1]];
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
        _formValues = [[NSMutableDictionary alloc] initWithCapacity:0];
        
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

- (NSString *)methodString
{
    return _method;
}

- (MAHTTPMethod)method
{
    if([self methodString])
    {
        if([[self methodString] isEqualToString:@"GET"])
            return kMAHTTPGetMethod;
        else if([[self methodString] isEqualToString:@"POST"])
            return kMAHTTPPostMethod;
        else if([[self methodString] isEqualToString:@"PUT"])
            return kMAHTTPPutMethod;
        else if([[self methodString] isEqualToString:@"HEAD"])
            return kMAHTTPHeadMethod;
        else if([[self methodString] isEqualToString:@"DELETE"])
            return kMAHTTPDeleteMethod;
        else if([[self methodString] isEqualToString:@"TRACE"])
            return kMAHTTPTraceMethod;
        else if([[self methodString] isEqualToString:@"OPTIONS"])
            return kMAHTTPOptionsMethod;
        else if([[self methodString] isEqualToString:@"CONNECT"])
            return kMAHTTPConnectMethod;
        else if([[self methodString] isEqualToString:@"PATH"])
            return kMAHTTPPathMethod;
    }
    
    return kMAHTTPNotDefined; 
}

- (NSString *)resource
{
    return _resource; 
}

- (NSString *)resourceExtension
{
    return [_resource pathExtension];
}

- (NSInteger)expectedContentLength
{
    if([_header objectForKey:@"Content-Length"])
        return [[_header objectForKey:@"Content-Length"] integerValue];

    return 0;
}

- (id)formValueForKey: (NSString *)key
{
    return [_formValues objectForKey:key];
}

- (NSDictionary *)formValues
{
    return _formValues;
}

- (void)setContent: (NSData *)data
{
    [_content release];
    _content = [data copy];
    
    if([self method] == kMAHTTPPostMethod && 
       [_header objectForKey:@"Content-Type"] && 
       [[_header objectForKey:@"Content-Type"] isEqualToString:@"application/x-www-form-urlencoded"])
    {
        [self _parseFormValues:[NSString stringWithUTF8String:[data bytes]]];
    }
}

- (NSData *)content
{
    return _content;
}

- (void)dealloc
{
    [_formValues release];
    [_method release];
    [_resource release];
    [_content release];
    [_header release];
    [super dealloc];
}

@end
