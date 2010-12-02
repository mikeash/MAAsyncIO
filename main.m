#import <Foundation/Foundation.h>

#import "MAAsyncReader.h"


int main (int argc, const char * argv[])
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    int fd = open("/dev/null", O_RDONLY);
    MAAsyncReader *reader = [[MAAsyncReader alloc] initWithFileDescriptor: fd];
    [reader setErrorHandler: ^(int err) {
        NSLog(@"got error %d (%s)", err, strerror(err));
    }];
    
    [reader readUntilCondition: ^NSUInteger (NSData *buffer) { return 0; }
                      callback: ^(NSData *data) {
                          NSLog(@"got data %@", data);
                          if(!data)
                              exit(0);
                      }];
    
    dispatch_main();
    [pool drain];
    return 0;
}
