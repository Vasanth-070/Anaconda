import Core
import Foundation
import Persistence
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

/// Stub + spy: `find` returns the entry the test chose (so freshness is forced, not computed),
/// and `store` only records. It holds no state. For real store-then-find behaviour use
/// `AcCache` with `FakeClock`.
actor SpyCache: Cache {
  typealias Value = Quote

  private let entry: CachedValue<Quote>?
  private(set) var storedQuotes: [Quote] = []

  init(entry: CachedValue<Quote>?) {
    self.entry = entry
  }

  func find(for key: String) async -> CachedValue<Quote>? {
    entry
  }

  func store(_ value: Quote, for key: String) async {
    storedQuotes.append(value)
  }
}

/// One clock the test can move forward between a store and a read.
final class FakeClock: ClockProtocol, @unchecked Sendable {
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
