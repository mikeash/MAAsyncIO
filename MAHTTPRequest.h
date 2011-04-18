//
//  MAHTTPRequest.h
//  MAAsyncIO
//
//  Created by Raphael Bartolome on 14.04.11.
//  Copyright 2011 Raphael Bartolome. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MAHTTPRequest : NSObject {
@private
    NSString *_methodType;
    NSString *_method;
    NSInteger _headerLength;
    NSMutableDictionary *_header;
    NSData *_content;
}

- (id)initWithHeader: (NSData *)header;

- (NSDictionary *)header;
- (NSInteger)headerLength;

- (NSString *)method;
- (NSString *)methodType;

- (NSInteger)expectedContentLength;

- (void)setContent: (NSData *)data;
- (NSData *)content;

@end
