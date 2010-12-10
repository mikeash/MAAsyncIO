MAAsyncIO
---------

MAAsyncIO is a wrapper around Grand Central Dispatch file descriptor sources. It's still a work in progress. Please feel free to make additions or requests.

MAAsyncIO is distributed under a BSD license, which can be found in the LICENSE file.


Reading
-------

`MAAsyncReader` handles reading. Create one using `initWithFileDescriptor:`. Optionally set an error handler and a target queue.

The basic reading method is `readUntilCondition:callback:`. This reads data from the file descriptor into a buffer. Each time it reads, the condition block is invoked. If the condition block returns a byte index, that much data is sliced off the buffer and the callback is called with that chunk of data. If the condition block returns `NSNotFound`, then it keeps reading.

Several convenience methods are implemented on top of this. The `readBytes:callback:` method reads exactly the number of bytes requested, and passes them to the callback. `readUntilData:callback:` reads until the provided data is found within the buffer, and gives the callback everything that was found up to that point. `readUntilCString:callback:` does the same, except the data is provided as a C string.

As an example, here's how you could read one line from a file:

    MAAsyncReader *reader = [[MAAsyncReader alloc] initWithFileDescriptor: someFD];
    [reader readUntilCString: "\n" callback: ^(NSData *lineData) {
        [reader readBytes: 1 callback: ^{ // read the newline too
            // do something with 'line'
        }];
    }];

This is all done completely asynchronously and nonblocking. By default, the "do something" code will run on the global dispatch queue, meaning it runs in the background and concurrently. By using `setTargetQueue:`, you can make it run on the dispatch queue of your choice, including the main thread.


Writing
-------

`MAAsyncWriter` handles writing. As with the reader, you create one with `initWithFileDescriptor:` and optionally set an error handler and target queue.

You can call `writeData:` and `writeCString:` as much as you want. The data so written is appended to a buffer, and that buffer is then written to the file descriptor as needed.

If you wish to regulate the rate at which data is written, you can use the write callback and the `-bufferSize` method. For example, here's how you could fetch or generate new data to write any time the buffer drops below 4kB of data:

    MAAsyncWriter *writer = [[MAAsyncWriter alloc] initWithFileDescriptor: someFD];
    [writer setDidWriteCallback: ^{
        if([writer bufferSize] < 4096)
            [writer writeData: [self _generateMoreData]];
    }];
    
    // get the ball rolling
    [writer writeData: [self _generateMoreData]];


Descriptor Management
---------------------

File descriptors are managed using a reference counting scheme similar to that used by Cocoa for memory management.

The `MAFDRetain` function increments the reference count of a file descriptor. The `MAFDRelease` function decrements the reference count, and closes the file descriptor if it reaches zero. File descriptors are considered to be created with a reference count of `1`. `MAAsyncReader` and `MAAsyncWriter` will retain their file descriptors while working on them, and release them when done.

Here's an example of how to properly use these functions:

    int fd = open(...); // implicit retain count of 1
    MAAsyncReader *reader = [[MAAsyncReader alloc] initWithFileDescriptor: fd];
    MAFDRelease(fd);
    
    // now use reader

These semantics make it possible to share an fd among multiple objects, so that you can have a reader and a writer both pointing at the same file descriptor:

    int fd = open(...); // implicit retain count of 1
    MAAsyncReader *reader = [[MAAsyncReader alloc] initWithFileDescriptor: fd];
    MAAsyncWriter *writer = [[MAAsyncWriter alloc] initWithFileDescriptor: fd];
    MAFDRelease(fd);
    
    // now use reader and writer


Sockets
-------

The async readers and writers make a natural interface to TCP sockets, whose unpredictable delays make asynchronous handling extremely advantageous. MAAsyncIO provides ways to create reader/writer pairs for a connected socket.

The `MAAsyncSocketConnect` function connects to an address/port pair and then invokes its callback, passing a reader/writer pair that the callback can then use.

The `MAAsyncHost` function provides asynchronous DNS lookups using a block callback. It can also attempt a connection to the looked up addresses by trying them sequentially with `MAAsyncSocketConnect`. With this, you can easily connect to a remote server:

    [[MAAsyncHost hostWithName: @"www.google.com"] connectToPort: 80 callback: ^(MAAsyncReader *reader, MAAsyncWriter *writer, NSError *error) {
        // check error
        // connected, use reader/writer to communicate  
    }];

`MAAsyncSocketListener` can be used to bind a listening socket that automatically accepts new connections and invokes a callback with a reader/writer pair fon the new connection. The `+listenerWithAddress:error:` method can be used to create a listener that's bound to a single address. The `+listenerWith4and6WithPortRange:tryRandom:error:` is a more sophisticated method which will bind both an IPv4 and IPv6 socket to the same port. You can specify a port range to try, and specify whether or not to try random ports if all of the ports in the given range are taken. If you don't care about the port, you can pass `NSMakeRange(0, 0)` as the range to have it only try random ports.

Here's an example server which simply writes "hello" to any client:

    MAAsyncSocketListener *listener = [MAAsyncSocketListener listenerWith4and6WithPortRange: NSMakeRange(0, 0) tryRandom: YES error: NULL];
    [listener setAcceptCallback: ^(MAAsyncReader *reader, MAAsyncWriter *writer, NSData *peerAddress) {
        [writer writeCString: "hello"];
    }];


Work In Progress
----------------

As stated above, MAAsyncIO is a work in progress. In particular, the following areas are deficient:

- The reader has no buffer limits, so it can go forever if the data never meets the conditions.

- The rules for when it's safe to invalidate objects (e.g. you can't invalidate a suspended `MAFDSource`) are too confusing. Everything should be made more robust in this respect.

- Everything needs more and better tests.

I plan to gradually work on these, but help is always appreciated.
