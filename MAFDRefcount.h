//
//  MAFDRefcount.h
//  MAAsyncIO
//
//  Created by Mike Ash on 12/7/10.
//  Copyright 2010 Mike Ash. All rights reserved.
//

#import <Cocoa/Cocoa.h>


int MAFDRetain(int fd);
void MAFDRelease(int fd);
