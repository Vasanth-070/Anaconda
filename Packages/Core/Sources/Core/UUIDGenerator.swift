import Foundation

/// Source of new UUIDs, injected so tests can get predictable ids.
public protocol UUIDGenerator: Sendable {
  func make() -> UUID
}

/// Production `UUIDGenerator`: a random UUID each call.
public struct AcUUIDGenerator: UUIDGenerator {
  public init() {}

  public func make() -> UUID { UUID() }
}
