import AsyncAlgorithms
import AsyncBroadcaster
import Foundation
import Testing

@Suite struct SubjectTests {

  @Test func testBasic() async throws {
    let stream = [1, 2, 3].async.broadcast()
    let one = Task {
      var result: [Int] = []
      for await i in stream {
        result.append(i)
      }
      return result
    }

    await #expect(one.value == [1, 2, 3])

  }

  @Test func testBasicBroadcast() async throws {
    let channel = AsyncBroadcaster.makeAsyncBroadcaster(of: Int.self)

    let task = Task {
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

    try await Task.sleep(for: .milliseconds(100))

    channel.continuation.finish()

    let results = await task.value

    #expect(results == [1, 2, 3])
  }

  @Test func testMultipleSubscribers() async throws {
    let channel = AsyncBroadcaster.makeAsyncBroadcaster(of: Int.self)

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
  }

  @Test func testStoreLatest() async throws {
    let channel = AsyncBroadcaster.makeAsyncBroadcaster(of: Int.self, replaying: .latest(1))

    channel.continuation.yield(42)
    var results: [Int] = []
    Task {
      try await Task.sleep(for: .milliseconds(200))
      channel.continuation.finish()
    }
    for await value in channel.stream {
      results.append(value)
    }
    #expect(results == [42])
  }

  @Test func testBasicBroadcast2() async throws {
    let channel = AsyncBroadcaster.makeAsyncBroadcaster(of: Int.self, replaying: .latest(3))

    let task = Task {
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

    let results = await task.value

    #expect(results == [1, 2, 3])
  }

  @Test func testMultipleSubscribers2() async throws {
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
        try? await Task.sleep(for: .milliseconds(100))
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
  }

  @Test func testMemoryPolicyLatest() async throws {
    let channel = AsyncBroadcaster.makeAsyncBroadcaster(of: Int.self, replaying: .latest(1))

    channel.continuation.yield(42)

    try await Task.sleep(for: .milliseconds(100))

    let task = Task {
      var results: [Int] = []

      for await value in channel.stream {
        results.append(value)
      }
      return results
    }

    try await Task.sleep(for: .milliseconds(100))

    channel.continuation.yield(99)

    channel.continuation.finish()

    let results = await task.value

    #expect(results == [42, 99])
  }

  @Test func testMemoryPolicyNone() async throws {
    let subject = AsyncBroadcaster.makeAsyncBroadcaster(of: Int.self, replaying: .none)
    let sem = TokenBucket(tokens: 1)
    await sem.wait()
    subject.continuation.yield(42)

    let task = Task {
      var results: [Int] = []
      sem.signal()
      for await value in subject.stream {
        results.append(value)
      }
      return results
    }

    await sem.wait()
    try await Task.sleep(for: .milliseconds(200))

    subject.continuation.yield(99)

    subject.continuation.finish()

    let results = await task.value

    #expect(results == [99])
  }

  @Test func testYieldMethod() async throws {
    let subject = AsyncBroadcaster.makeAsyncBroadcaster(of: Int.self, replaying: .none)

    let task = Task {
      var results: [Int] = []

      for await value in subject.stream {
        results.append(value)

        try await Task.sleep(for: .milliseconds(10))
      }
      return results
    }

    try await Task.sleep(for: .milliseconds(100))

    subject.continuation.yield(1)
    subject.continuation.yield(2)
    subject.continuation.yield(3)
    subject.continuation.finish()
    let results = try await task.value

    #expect(results == [1, 2, 3])
  }

  @Test func testFinishWithNoSubscribers() async throws {
    let subject = AsyncBroadcaster.makeAsyncBroadcaster(of: Int.self, replaying: .none)

    subject.continuation.yield(1)

    subject.continuation.finish()

    let task = Task {
      var results: [Int] = []

      for await value in subject.stream {
        results.append(value)
      }
      return results
    }

    let results = await task.value

    #expect(results.isEmpty)
  }

  @Test func testManySubscribers() async throws {

    let __printDetails: Bool = false
    let subscriberCount: Int = 500
    let iterationCount: Int = 92

    let emitter = AsyncBroadcaster.makeAsyncBroadcaster(of: Int.self, replaying: .none)
    let sem = TokenBucket(tokens: 500)
    let reachedCountSem = TokenBucket(tokens: 500)
    let finSem = TokenBucket(tokens: 500)
    let subscribers = (0..<subscriberCount)
      .map { _ in
        Task {
          var results = [Int]()
          Task {
            sem.signal()
          }
          for await value in emitter.stream {
            results.append(value)
            if value == 7_540_113_804_746_346_429 {
              reachedCountSem.signal()
            }
          }
          finSem.signal()
          return results
        }
      }

    await sem.wait()

    let yieldPatience = 1000
    for _ in 0..<subscriberCount {

      for _ in 0..<yieldPatience {
        await Task.yield()
      }
    }

    var fibResult: [Int] = []
    var last: Int? = nil
    var curr: Int? = nil
    func fib() async {
      let emit: Int
      if last == nil {
        emit = 1
        last = emit
      } else if curr == nil {
        emit = 1
        curr = emit
      } else if let oldLast = last, let oldCurr = curr {
        emit = oldLast + oldCurr
        last = oldCurr
        curr = emit
      } else {
        fatalError()
      }
      emitter.continuation.yield(emit)
      fibResult.append(emit)
    }
    for _ in 0..<iterationCount {
      await fib()
    }
    await reachedCountSem.wait()
    emitter.continuation.finish()

    await finSem.wait()

    let (track, output): (() -> Void, () -> Void) = {
      guard __printDetails else {
        return {
          return ({}, {})
        }()
      }
      print("expecting \(subscriberCount) x results")
      print(fibResult)
      return {
        var count = 0
        return (
          { () -> Void in
            count += 1
          },
          { () -> Void in
            print("received count: \(count)")
          }
        )
      }()
    }()

    for subscribe in subscribers {
      let results = await subscribe.value
      #expect(results == fibResult)
      track()
    }
    output()

  }

  @Test func testBroadcast() async throws {

    let __printDetails: Bool = false
    let subscriberCount: Int = 500
    let iterationCount: Int = 92

    let upstream = AsyncStream.makeStream(of: Int.self)
    let stream = AsyncBroadcaster(replay: .unbounded, sequence: upstream.stream)
    let sem = TokenBucket(tokens: 500)
    let reachedCountSem = TokenBucket(tokens: 500)
    let finSem = TokenBucket(tokens: 500)
    let subscribers = (0..<subscriberCount)
      .map { _ in
        Task {
          var results = [Int]()
          Task {
            sem.signal()
          }
          for await value in stream {
            results.append(value)
            if value == 7_540_113_804_746_346_429 {
              reachedCountSem.signal()
            }
          }
          finSem.signal()
          return results
        }
      }

    await sem.wait()

    let yieldPatience = 1000
    for _ in 0..<subscriberCount {

      for _ in 0..<yieldPatience {
        await Task.yield()
      }
    }

    var fibResult: [Int] = []
    var last: Int? = nil
    var curr: Int? = nil
    func fib() async {
      let emit: Int
      if last == nil {
        emit = 1
        last = emit
      } else if curr == nil {
        emit = 1
        curr = emit
      } else if let oldLast = last, let oldCurr = curr {
        emit = oldLast + oldCurr
        last = oldCurr
        curr = emit
      } else {
        fatalError()
      }
      upstream.continuation.yield(emit)
      fibResult.append(emit)
    }
    for _ in 0..<iterationCount {
      await fib()
    }
    await reachedCountSem.wait()
    upstream.continuation.finish()

    await finSem.wait()

    let (track, output): (() -> Void, () -> Void) = {
      guard __printDetails else {
        return {
          return ({}, {})
        }()
      }
      print("expecting \(subscriberCount) x results")
      print(fibResult)
      return {
        var count = 0
        return (
          { () -> Void in
            count += 1
          },
          { () -> Void in
            print("received count: \(count)")
          }
        )
      }()
    }()

    for subscribe in subscribers {
      let results = await subscribe.value
      #expect(results == fibResult)
      track()
    }
    output()

  }

}
