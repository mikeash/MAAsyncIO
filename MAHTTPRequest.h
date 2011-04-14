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
    NSMutableDictionary *_request;
}

- (id)initWithHeader: (NSData *)header;

- (NSDictionary *)request;

- (NSString *)method;
- (NSString *)methodType;

- (NSInteger)expectedContentLength;

- (void)setContent: (NSData *)data;
- (NSData *)content;

@end
