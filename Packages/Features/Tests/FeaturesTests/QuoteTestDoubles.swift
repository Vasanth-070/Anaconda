import Foundation
@testable import Features

/// Returns a canned result and counts calls, so tests can assert "API was / wasn't hit".
actor StubAPIClient: QuoteAPIClient {
  private let result: Result<Quote, QuoteError>
  private(set) var callCount = 0
  private(set) var requestedSymbols: [String] = []

  init(result: Result<Quote, QuoteError>) {
    self.result = result
  }

  func fetch(for symbol: String) async -> Result<Quote, QuoteError> {
    callCount += 1
    requestedSymbols.append(symbol)
    return result
  }
}

/// Cache whose freshness is decided by the test, and which records what was stored.
actor FakeCache: QuoteCache {
  private let entry: CachedQuote?
  private(set) var storedQuotes: [Quote] = []

  init(entry: CachedQuote?) {
    self.entry = entry
  }

  func find(for symbol: String) async -> CachedQuote? {
    entry
  }

  func store(_ quote: Quote) async {
    storedQuotes.append(quote)
  }
}

/// One clock the test can move forward between a store and a read.
final class FakeClock: ACClockProtocol, @unchecked Sendable {
  private let lock = NSLock()
  private var now: Date

  init(now: Date = Date(timeIntervalSince1970: 1_000_000)) {
    self.now = now
  }

  var current: Date {
    lock.lock(); defer { lock.unlock() }
    return now
  }

  func advance(by seconds: TimeInterval) {
    lock.lock(); defer { lock.unlock() }
    now = now.addingTimeInterval(seconds)
  }
}

extension Quote {
  static func sample(symbol: String = "AAPL", price: Double = 100, change: Double = 1) -> Quote {
    Quote(symbol: symbol, price: price, change: change)
  }
}
