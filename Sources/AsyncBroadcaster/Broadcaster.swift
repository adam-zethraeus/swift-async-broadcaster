public final class AsyncBroadcaster<Element: Sendable>: AsyncSequence, Sendable {

  public typealias Element = Element

  public init<S: AsyncSequence>(replay: AsyncBuffer, sequence: sending S)
  where S.Element == Element {
    let controller = MulticastController<Element>(
      sequence.map(MulticastController.Event.publish), replay: replay)
    self.controller = controller
    self.memory = replay
  }

  let controller: MulticastController<Element>
  let memory: AsyncBuffer

  public func makeAsyncIterator() -> Iterator {
    let underlying = AsyncStream<Element>
      .makeStream(
        of: Element.self,
        bufferingPolicy: .unbounded
      )
    controller.handle(.subscribe(underlying.continuation))
    return Iterator(underlying: underlying.stream.makeAsyncIterator())
  }

  public struct Iterator: AsyncIteratorProtocol {
    init(underlying: AsyncStream<Element>.Iterator) {
      self.underlying = underlying
    }
    private var underlying: AsyncStream<Element>.Iterator
    public mutating func next() async -> Element? {
      await underlying.next()
    }
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, *)
    public mutating func next(isolation: isolated (any Actor)?) async throws(Never)
      -> Element?
    {
      await underlying.next(isolation: isolation)
    }
  }
}

extension AsyncSequence where Self: Sendable, Self.Element: Sendable {
  public func broadcast(replay: AsyncBuffer = .none) -> AsyncBroadcaster<Element> {
    AsyncBroadcaster(replay: replay, sequence: self)
  }
}
