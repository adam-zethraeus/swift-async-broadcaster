# AsyncBroadcaster

Broadcasting/Multicasting for Swift's AsyncSequences

Swift's `AsyncSequence` protocol backs the `for await value in stream { /* ... */ }` syntax.
This is a nice pattern with an annoying constraint: multiple subscribers are unsupported by default.
It's up to the author of the async sequence's data source to ensure each consumer receives its own `AsyncIteratorProtocol` to iterate on — and neither the Swift language nor the official AsyncAlgorithms package provide operators which 'broadcast' an existing AsyncSequence.

Async sequences created with `AsyncStream.makeStream(of:)` or with any of the operators from AsyncAlgorithms **can not emit to multiple subscribers**.

Instance of `AsyncBroadcaster`, whether created directly or through a call to `.broadcast()`, **can**.

## Features

- **Broadcast**: make an AsyncSequence safe for multiple subscribers.
- **Yield**: synchronously yield values to an AsyncBroadcaster.
- **Replay behavior**: Control how new subscribers receive past values
  - `.none`: No replay
  - `.latest(n)`: Replay up to n most recent values
  - `.unbounded`: Replay all historical values

(As of v `0.0.1` this is a buffering, not a backpressure, based system.)

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/adam-zethraeus/AsyncBroadcaster.git", from: "0.0.1")
]
```

## Usage

### Basic Example

```swift

    let stream = [1,2,3].async.broadcast()

    let one = Task {
      var result: [Int] = []
      for await i in stream {
        result.append(i)
      }
      return result
    }

    await #expect(one.value == [1,2,3])
```

### Synchronously emitting to a Broadcaster's Continuation

```swift
let channel = AsyncBroadcaster.makeAsyncBroadcaster(of: Int.self, replaying: .latest(3))

let task1 = Task {
  var results: [Int] = []
  for await value in channel.stream {
    results.append(value)
  }
  return results
}

let task2 = Task {
  var results: [Int] = []
  for await value in channel.stream {
    results.append(value)
  }
  return results
}

try await Task.sleep(for: .milliseconds(100))

channel.continuation.yield(1)
channel.continuation.yield(2)
channel.continuation.yield(3)
channel.continuation.finish()
let results1 = await task1.value
let results2 = await task2.value

#expect(results1 == [1, 2, 3])
#expect(results2 == [1, 2, 3])
```

## License

MIT
