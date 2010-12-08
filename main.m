#import <Foundation/Foundation.h>

#import <netdb.h>

#import "MAAsyncHost.h"
#import "MAAsyncReader.h"
#import "MAAsyncWriter.h"
#import "MAFDRefcount.h"
#import "MAAsyncSocketUtils.h"


static void WithPool(void (^block)(void))
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    block();
    [pool release];
}

static int gFailureCount;

static void Test(void (*func)(void), const char *name)
{
    WithPool(^{
        int failureCount = gFailureCount;
        NSLog(@"Testing %s", name);
        func();
        NSLog(@"%s: %s", name, failureCount == gFailureCount ? "SUCCESS" : "FAILED");
    });
}

#define TEST(func) Test(func, #func)

#define TEST_ASSERT(cond, ...) do { \
        if(!(cond)) { \
            gFailureCount++; \
            NSString *message = [NSString stringWithFormat: @"" __VA_ARGS__]; \
            NSLog(@"%s:%d: assertion failed: %s %@", __func__, __LINE__, #cond, message); \
        } \
    } while(0)

static BOOL WaitFor(int (^block)(void))
{
    NSProcessInfo *pi = [NSProcessInfo processInfo];
    
    NSTimeInterval start = [pi systemUptime];
    __block BOOL stop;
    do
    {
        WithPool(^{
            stop = block() != 0;
        });
    } while(!stop && [pi systemUptime] - start < 10);
    
    return stop;
}

static MAAsyncReader *Reader(int fd)
{
    MAAsyncReader *reader = [[MAAsyncReader alloc] initWithFileDescriptor: fd];
    [reader setErrorHandler: ^(int err) {
        NSLog(@"got error %d (%s)", err, strerror(err));
        abort();
    }];
    return [reader autorelease];
}

static MAAsyncWriter *Writer(int fd)
{
    MAAsyncWriter *writer = [[MAAsyncWriter alloc] initWithFileDescriptor: fd];
    [writer setErrorHandler: ^(int err) {
        NSLog(@"got error %d (%s)", err, strerror(err));
        abort();
    }];
    return [writer autorelease];
}

static void WithPipe(void (^block)(MAAsyncReader *reader, MAAsyncWriter *writer))
{
    int fds[2];
    int ret = pipe(fds);
    TEST_ASSERT(ret == 0);
    
    int readFD = fds[0];
    int writeFD = fds[1];
    
    MAAsyncReader *reader = Reader(readFD);
    MAAsyncWriter *writer = Writer(writeFD);
    
    MAFDRelease(readFD);
    MAFDRelease(writeFD);
    
    block(reader, writer);
}

static void TestDevNull(void)
{
    for(int i = 0; i < 1000; i++)
        WithPool(^{
            int fd = open("/dev/null", O_RDONLY);
            
            MAAsyncReader *reader = Reader(fd);
            MAFDRelease(fd);
            
            __block BOOL didRead = NO;
            [reader readUntilCondition: ^NSUInteger (NSData *buffer) { return NSNotFound; }
                              callback: ^(NSData *data) {
                                  TEST_ASSERT(!data);
                                  didRead = YES;
                              }];
            WaitFor(^int { return didRead; });
        });
}

static void TestPipe(void)
{
    for(int i = 0; i < 1000; i++)
        WithPool(^{
            WithPipe(^(MAAsyncReader *reader, MAAsyncWriter *writer) {
                NSData *d1 = [NSData dataWithBytes: "12345" length: 5];
                NSData *d2 = [NSData dataWithBytes: "abcdef" length: 6];
                NSData *d3 = [NSData dataWithBytes: "ghijkl" length: 6];
                
                __block BOOL done = NO;
                
                [reader readBytes: 5 callback: ^(NSData *data) {
                    TEST_ASSERT([data isEqualToData: d1]);
                    [reader readUntilCString: "\n" callback: ^(NSData *data) {
                        TEST_ASSERT([data isEqualToData: d2]);
                        [reader readBytes: 1 callback: ^(NSData *data) {
                            [reader readUntilCString: "\r\n" callback: ^(NSData *data) {
                                TEST_ASSERT([data isEqualToData: d3]);
                                [reader readBytes: 2 callback: ^(NSData *data) {
                                    [reader readUntilCString: "\r\n" callback: ^(NSData *data) {
                                        TEST_ASSERT(data && [data length] == 0);
                                        done = YES;
                                    }];
                                }];
                            }];
                        }];
                    }];
                }];
                
                [writer writeData: d1];
                [writer writeData: d2];
                [writer writeCString: "\n"];
                [writer writeData: d3];
                [writer writeCString: "\r\n"];
                [writer writeCString: "\r\n"];
                
                TEST_ASSERT(WaitFor(^int { return done; }));
            });
        });
}

static void TestHost(void)
{
    __block BOOL done1 = NO;
    __block BOOL done2 = NO;
    [[MAAsyncHost hostWithName: @"localhost"] resolve: ^(NSArray *addresses, CFStreamError error) {
        TEST_ASSERT(addresses);
        TEST_ASSERT(!error.domain);
        done1 = YES;
    }];
    [[MAAsyncHost hostWithName: @"sdrgaoigdsaeuindthaeuihtedonutidenoscuhdnhe"] resolve: ^(NSArray *addresses, CFStreamError error) {
        TEST_ASSERT(!addresses);
        TEST_ASSERT(error.domain == kCFStreamErrorDomainNetDB);
        TEST_ASSERT(error.error == EAI_NONAME);
        done2 = YES;
    }];
    
    TEST_ASSERT(WaitFor(^int { return done1; }));
    TEST_ASSERT(WaitFor(^int { return done2; }));
}

static void TestSocket(void)
{
    __block BOOL done = NO;
    [[MAAsyncHost hostWithName: @"www.google.com"] resolve: ^(NSArray *addresses, CFStreamError error) {
        TEST_ASSERT([addresses count]);
        NSData *address = [addresses objectAtIndex: 0];
        MAAsyncSocketConnect(address, 80, ^(MAAsyncReader *reader, MAAsyncWriter *writer, NSError *error) {
            [writer writeCString: "GET /\n\n"];
            [reader readBytes: 1 callback: ^(NSData *data) {
                done = YES;
                
                [reader self];
                [writer self];
            }];
        });
    }];
    
    TEST_ASSERT(WaitFor(^int { return done; }));
}

int main(int argc, const char **argv)
{
    WithPool(^{
        TEST(TestDevNull);
        TEST(TestPipe);
        TEST(TestHost);
        TEST(TestSocket);
        
        NSString *message;
        if(gFailureCount)
            message = [NSString stringWithFormat: @"FAILED: %d total assertion failure%s", gFailureCount, gFailureCount > 1 ? "s" : ""];
        else
            message = @"SUCCESS";
        NSLog(@"Tests complete: %@", message);
    });
    return 0;
}
