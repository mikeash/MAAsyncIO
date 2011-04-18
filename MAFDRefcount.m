//
//  MAFDRefcount.m
//  MAAsyncIO
//
//  Created by Mike Ash on 12/7/10.
//  Copyright 2010 Mike Ash. All rights reserved.
//

#import "MAFDRefcount.h"


static CFMutableDictionaryRef gRefcounts;
static dispatch_queue_t gQueue;

static void Init(void)
{
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        gRefcounts = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
        gQueue = dispatch_queue_create("com.mikesah.MAFDRefcount", NULL);
    });
}

static int GetRefcount(int fd)
{
    void *value;
    Boolean present = CFDictionaryGetValueIfPresent(gRefcounts, (void *)(intptr_t)fd, (void *)&value);
    return present ? (intptr_t)value : 1;
}

static void SetRefcount(int fd, int count)
{
    if(count == 1) // 1 is represented by not having an entry
        CFDictionaryRemoveValue(gRefcounts, (void *)(intptr_t)fd);
    else
        CFDictionarySetValue(gRefcounts, (void *)(intptr_t)fd, (void *)(intptr_t)count);
}

static void Destroy(int fd)
{
    close(fd);
}

int MAFDRetain(int fd)
{
    Init();
    
    dispatch_sync(gQueue, ^{
        SetRefcount(fd, GetRefcount(fd) + 1);
    });
    
    return fd;
}

void MAFDRelease(int fd)
{
    dispatch_sync(gQueue, ^{
        int count = GetRefcount(fd);
        if(count == 1)
            Destroy(fd);
        else
            SetRefcount(fd, count - 1);
    });
}
