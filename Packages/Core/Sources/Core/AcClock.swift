import Foundation

/// Production `ClockProtocol`: the real system time.
public struct AcClock: ClockProtocol {
  public init() {}

  public var current: Date { Date() }
}
