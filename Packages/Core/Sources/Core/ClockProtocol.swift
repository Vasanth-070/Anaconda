import Foundation

/// Source of the current time, injected so tests can control it.
public protocol ClockProtocol: Sendable {
  var current: Date { get }
}
