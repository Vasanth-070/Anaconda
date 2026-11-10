import Foundation

enum QuoteAnalyticsEvent: Equatable, Sendable {
  case loaded(symbol: String)
  case stale(symbol: String)
  case failed(symbol: String, error: QuoteError)
}

protocol AnalyticsTracker: Sendable {
  func track(_ event: QuoteAnalyticsEvent)
}
