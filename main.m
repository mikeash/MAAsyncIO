#import <Foundation/Foundation.h>

#import <netdb.h>

#import "MAAsyncHost.h"
#import "MAAsyncHTTPServer.h"
#import "MAAsyncReader.h"
#import "MAAsyncWriter.h"
#import "MAAsyncSocketListener.h"
#import "MAAsyncSocketUtils.h"
#import "MAFDRefcount.h"


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
            [reader readUntilCondition: ^NSRange (NSData *buffer) { return MAKeepReading; }
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
                        [reader readUntilCString: "\r\n" callback: ^(NSData *data) {
                            TEST_ASSERT([data isEqualToData: d3]);
                            [reader readUntilCString: "\r\n" callback: ^(NSData *data) {
                                TEST_ASSERT(data && [data length] == 0);
                                done = YES;
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

static void TestHostMultipleResolution(void)
{
    __block BOOL done1 = NO;
    __block BOOL done2 = NO;
    
    MAAsyncHost *host = [MAAsyncHost hostWithName: @"localhost"];
    [host resolve: ^(NSArray *addresses, CFStreamError error) {
        TEST_ASSERT(addresses);
        TEST_ASSERT(!error.domain);
        done1 = YES;
    }];
    [host resolve: ^(NSArray *addresses, CFStreamError error) {
        TEST_ASSERT(addresses);
        TEST_ASSERT(!error.domain);
        done2 = YES;
    }];
    
    TEST_ASSERT(WaitFor(^{ return done1 && done2; }));
}

static void TestSocketConnect(void)
{
    __block BOOL done = NO;
    [[MAAsyncHost hostWithName: @"www.google.com"] connectToPort: 80 callback: ^(MAAsyncReader *reader, MAAsyncWriter *writer, NSError *error) {
        TEST_ASSERT(reader && writer, @"%@", error);
        if(reader && writer)
        {
            [writer writeCString: "GET /\n\n"];
            [reader readBytes: 1 callback: ^(NSData *data) {
                done = YES;
            }];
        }
    }];
    
    TEST_ASSERT(WaitFor(^int { return done; }));
}

static void TestSocketListen(void)
{
    NSError *error;
    MAAsyncSocketListener *listener = [MAAsyncSocketListener listenerWith4and6WithPortRange: NSMakeRange(1, 20) tryRandom: YES error: &error];
    TEST_ASSERT(listener, @"%@", error);
}

static void TestSocketBoth(void)
{
    NSError *error;
    MAAsyncSocketListener *listener = [MAAsyncSocketListener listenerWith4and6WithPortRange: NSMakeRange(1, 20) tryRandom: YES error: &error];
    TEST_ASSERT(listener, @"%@", error);
    
    __block BOOL done1 = NO;
    [listener setAcceptCallback: ^(MAAsyncReader *reader, MAAsyncWriter *writer, NSData *peerAddress) {
        [reader readBytes: 1 callback: ^(NSData *data) {
            TEST_ASSERT(*(const char *)[data bytes] == 'a');
            [writer writeCString: "b"];
            done1 = YES;
        }];
    }];
    
    __block BOOL done2 = NO;
    [[MAAsyncHost hostWithName: @"localhost"] connectToPort: [listener port] callback: ^(MAAsyncReader *reader, MAAsyncWriter *writer, NSError *error) {
        TEST_ASSERT(reader && writer, @"%@", error);
        if(reader && writer)
        {
            [writer writeCString: "a"];
            [reader readBytes: 1 callback: ^(NSData *data) {
                TEST_ASSERT(*(const char *)[data bytes] == 'b');
                done2 = YES;
            }];
        }
    }];
    TEST_ASSERT(WaitFor(^{ return done1 && done2; }));
}

static void TestSocketClosing(void)
{
    MAAsyncSocketListener *listener = [MAAsyncSocketListener listenerWith4and6WithPortRange: NSMakeRange(0, 0) tryRandom: YES error: NULL];
    TEST_ASSERT(listener);
    
    [listener setAcceptCallback: ^(MAAsyncReader *reader, MAAsyncWriter *writer, NSData *peerAddress) {
        [reader invalidate];
        [writer invalidate];
    }];
    
    __block BOOL done = NO;
    [[MAAsyncHost hostWithName: @"localhost"] connectToPort: [listener port] callback: ^(MAAsyncReader *reader, MAAsyncWriter *writer, NSError *error) {
        TEST_ASSERT(reader && writer, @"%@", error);
        if(reader && writer)
        {
            [reader readBytes: 1 callback: ^(NSData *data) {
                TEST_ASSERT(!data);
                done = YES;
            }];
        }
    }];
    TEST_ASSERT(WaitFor(^int { return done; }));
}

static void TestHTTP(void)
{
    NSError *error;
    MAAsyncHTTPServer *server = [[MAAsyncHTTPServer alloc] initWithPort: -1 error: &error];
    TEST_ASSERT(server, @"%@", error);
    
    NSData *data = [@"testing 1 2 3" dataUsingEncoding: NSUTF8StringEncoding];
    
    [server setResourceHandler: ^(NSString *resource, MAAsyncWriter *writer) {
        [writer writeData: data];
    }];
    
    NSURL *url = [NSURL URLWithString:
                  [NSString stringWithFormat: @"http://localhost:%d/", [server port]]];
    NSURLRequest *request = [NSURLRequest requestWithURL: url];
    
    NSURLResponse *response;
    NSData *responseData = [NSURLConnection sendSynchronousRequest: request returningResponse: &response error: &error];
    
    TEST_ASSERT(responseData, @"%@", error);
    TEST_ASSERT([responseData isEqualToData: data]);
    
    [server release];
}

int main(int argc, const char **argv)
{
    WithPool(^{
        TEST(TestDevNull);
        TEST(TestPipe);
        TEST(TestHost);
        TEST(TestHostMultipleResolution);
        TEST(TestSocketConnect);
        TEST(TestSocketListen);
        TEST(TestSocketBoth);
        TEST(TestSocketClosing);
        TEST(TestHTTP);
        
        NSString *message;
        if(gFailureCount)
            message = [NSString stringWithFormat: @"FAILED: %d total assertion failure%s", gFailureCount, gFailureCount > 1 ? "s" : ""];
        else
            message = @"SUCCESS";
        NSLog(@"Tests complete: %@", message);
    });
    return 0;
}
