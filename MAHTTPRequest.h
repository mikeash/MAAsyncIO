//
//  MAHTTPRequest.h
//  MAAsyncIO
//
//  Created by Raphael Bartolome on 14.04.11.
//  Copyright 2011 Raphael Bartolome. All rights reserved.
//

#import <Foundation/Foundation.h>

enum kMAHTTPMethod {
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
};

typedef NSUInteger MAHTTPMethod;

@interface MAHTTPRequest : NSObject {
@private
    NSString *_resource;
    NSString *_method;
    NSInteger _headerLength;
    NSMutableDictionary *_header;
    NSMutableDictionary *_formValues;
    NSData *_content;
}

- (id)initWithHeader: (NSData *)header;

- (NSDictionary *)header;
- (NSInteger)headerLength;

- (NSString *)methodString;
- (MAHTTPMethod)method;
- (NSString *)resource;
- (NSString *)resourceExtension;

- (NSInteger)expectedContentLength;

- (id)formValueForKey: (NSString *)key;
- (NSDictionary *)formValues;

- (void)setContent: (NSData *)data;
- (NSData *)content;

@end
