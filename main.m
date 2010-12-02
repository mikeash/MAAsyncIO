#import <Foundation/Foundation.h>

#import "MAAsyncReader.h"


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

static void TestDevNull(void)
{
    int fd = open("/dev/null", O_RDONLY);
    MAAsyncReader *reader = [[MAAsyncReader alloc] initWithFileDescriptor: fd];
    [reader setErrorHandler: ^(int err) {
        NSLog(@"got error %d (%s)", err, strerror(err));
        abort();
    }];
    
    __block BOOL didRead = NO;
    [reader readUntilCondition: ^NSUInteger (NSData *buffer) { return 0; }
                      callback: ^(NSData *data) {
                          TEST_ASSERT(!data);
                          didRead = YES;
                      }];
    WaitFor(^int { return didRead; });
}

int main(int argc, const char **argv)
{
    WithPool(^{
        TEST(TestDevNull);
        NSString *message;
        if(gFailureCount)
            message = [NSString stringWithFormat: @"FAILED: %d total assertion failure%s", gFailureCount, gFailureCount > 1 ? "s" : ""];
        else
            message = @"SUCCESS";
        NSLog(@"Tests complete: %@", message);
    });
    return 0;
}
