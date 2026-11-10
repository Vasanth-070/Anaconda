import Foundation

/// Small key-value storage, injected so tests don't touch the real `UserDefaults`.
public protocol KeyValueStore: Sendable {
  func string(forKey key: String) -> String?
  func set(_ value: String?, forKey key: String)
}

/// Production `KeyValueStore`: backed by `UserDefaults`.
/// `@unchecked Sendable`: `UserDefaults` is documented thread-safe but not marked `Sendable`.
public struct AcKeyValueStore: KeyValueStore, @unchecked Sendable {
  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func string(forKey key: String) -> String? {
    defaults.string(forKey: key)
  }

  public func set(_ value: String?, forKey key: String) {
    defaults.set(value, forKey: key)
  }
}
