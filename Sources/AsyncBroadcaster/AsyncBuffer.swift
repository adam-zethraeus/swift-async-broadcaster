public enum AsyncBuffer: Sendable {
  case none
  case latest(Int)
  case unbounded

  public func prune<T>(elements: inout [T]) {
    switch self {
    case .none:
      elements.removeAll()
    case .latest(let count):
      elements = elements.suffix(count)
    case .unbounded:
      break
    }
  }
}

extension AsyncStream.Continuation.BufferingPolicy {
  init(_ asyncBuffer: AsyncBuffer) {
    switch asyncBuffer {
    case .none:
      self = .bufferingNewest(0)
    case .latest(let count):
      self = .bufferingNewest(count)
    case .unbounded:
      self = .unbounded
    }
  }
}
