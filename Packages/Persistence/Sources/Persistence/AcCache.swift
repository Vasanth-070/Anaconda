import Core
import Foundation

/// In-memory `Cache`. Stamps entries with its own injected clock and decides freshness itself.
public actor AcCache<Value: Sendable>: Cache {
  private struct Entry {
    let value: Value
    let storedAt: Date
  }

  private var entries: [String: Entry] = [:]
  private let clock: ClockProtocol
  private let ttl: TimeInterval

  public init(clock: ClockProtocol, ttl: TimeInterval = 120) {
    self.clock = clock
    self.ttl = ttl
  }

  public func find(for key: String) -> CachedValue<Value>? {
    guard let entry = entries[key] else { return nil }
    let age = clock.current.timeIntervalSince(entry.storedAt)
    return CachedValue(value: entry.value, isFresh: age < ttl)
  }

  public func store(_ value: Value, for key: String) {
    entries[key] = Entry(value: value, storedAt: clock.current)
  }
}
