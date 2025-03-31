import Foundation
import OrderedCollections
import Synchronization

final class MulticastController<Element: Sendable>: Sendable {

  enum Event {
    case subscribe(_ continuation: AsyncStream<Element>.Continuation)
    case unsubscribe(id: UUID)
    case publish(Element)
    case finish
  }

  init<S: AsyncSequence>(_ sequence: sending S, replay: AsyncBuffer) where S.Element == Event {
    self.state = .init(.available(.init(replayCapacity: replay, replay: [], continuations: [:])))
    Task(priority: .high) { [weak self] in
      do {
        for try await event in sequence {
          guard let self else { return }
          self.handle(event)
        }
        self?.handle(.finish)
      } catch {
        self?.handle(.finish)
      }
    }
  }

  private let state: Mutex<State>

  func handle(_ event: Event) {
    let action: @Sendable () -> Void = state.withLock { state in
      switch event {
      case .finish:
        state.finish()
        return {}

      case .subscribe(let continuation):
        let id = UUID()
        switch state {
        case .available(var storage):
          storage.continuations[id] = continuation
          state = .available(storage)
          storage.recite(to: continuation)
          return {
            continuation.onTermination = { [weak self] c in
              if let self = self {

                switch c {
                case .finished:
                  break
                case .cancelled:
                  self.handle(.unsubscribe(id: id))
                @unknown default:
                  break
                }
              }
            }
          }
        case .finished(let elements):
          for element in elements {
            continuation.yield(element)
          }
          continuation.finish()
          return {}
        }
      case .unsubscribe(let id):
        switch state {
        case .available(var storage):
          storage.finish(id: id)
          state = .available(storage)
        case .finished:
          break
        }
        return {}
      case .publish(let element):
        switch state {
        case .available(var storage):
          storage.remember(element)
          state = .available(storage)
          for (_, continuation) in storage.continuations {
            continuation.yield(element)
          }
        default: break
        }
        return {}
      }
    }
    action()
  }

}

extension MulticastController {
  enum State {
    struct InvalidTransition: Error {}
    case available(Storage)
    case finished([Element])

    mutating func finish() {
      switch self {
      case .finished:
        return
      case .available(var storage):
        storage.finishAll()
        self = .finished(storage.replay)
      }
    }
  }
}

extension MulticastController {
  struct Storage {
    let replayCapacity: AsyncBuffer
    var replay: [Element] = []
    var continuations: OrderedDictionary<UUID, AsyncStream<Element>.Continuation> = [:]
    mutating func finish(id: UUID) {
      if let continuation = continuations[id] {
        continuations[id] = nil
        continuation.finish()
      }
    }
    mutating func finishAll() {
      replay.removeAll()
      let continuations = self.continuations
      self.continuations.removeAll()
      for (_, continuation) in continuations {
        continuation.finish()
      }
    }
    mutating func remember(_ element: Element) {
      replay.append(element)
      replayCapacity.prune(elements: &replay)
    }
    func recite(to continuation: AsyncStream<Element>.Continuation) {
      for element in replay {
        continuation.yield(element)
      }
    }
  }
}
