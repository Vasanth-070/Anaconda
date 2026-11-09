import Foundation

/// A cached value plus whether it is still within its TTL.
public struct CachedValue<Value: Sendable>: Sendable {
  public let value: Value
  public let isFresh: Bool

  public init(value: Value, isFresh: Bool) {
    self.value = value
    self.isFresh = isFresh
  }
}

/// Key-value cache. A stale entry is still returned (with `isFresh == false`) so callers
/// can fall back to it when a refresh fails.
public protocol Cache<Value>: Sendable {
  associatedtype Value: Sendable
  func find(for key: String) async -> CachedValue<Value>?
  func store(_ value: Value, for key: String) async
}
