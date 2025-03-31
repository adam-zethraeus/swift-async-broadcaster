extension AsyncBroadcaster {

  public struct Continuation: Sendable {
    let continuation: AsyncStream<Element>.Continuation

    public func yield(_ element: sending Element) {
      continuation.yield(element)
    }

    public consuming func finish() {
      continuation.finish()
    }
  }

  public static func makeAsyncBroadcaster(
    of: Element.Type = Element.self, replaying: AsyncBuffer = .none
  ) -> Subject {
    let upstream = AsyncStream.makeStream(of: Element.self)
    return Subject(
      stream: upstream.stream.broadcast(replay: replaying),
      continuation: .init(continuation: upstream.continuation))
  }

  public struct Subject: Sendable {
    public let stream: AsyncBroadcaster<Element>
    public let continuation: Continuation
  }
}
