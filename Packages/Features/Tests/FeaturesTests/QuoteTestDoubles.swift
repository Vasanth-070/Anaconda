import Core
import Foundation
import Persistence
import XCTest
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

/// Mock: the test states the expectation up front ("fetch AAPL exactly N times") and
/// `verify` fails the test if reality differs. A stub only answers; a mock judges.
actor MockQuoteAPI: QuoteAPIClient {
  private let result: Result<Quote, QuoteError>
  private let expectedSymbol: String
  private let expectedCalls: Int
  private var symbols: [String] = []

  init(
    expectedSymbol: String,
    expectedCalls: Int = 1,
    result: Result<Quote, QuoteError> = .success(.sample())
  ) {
    self.expectedSymbol = expectedSymbol
    self.expectedCalls = expectedCalls
    self.result = result
  }

  func fetch(for symbol: String) async -> Result<Quote, QuoteError> {
    symbols.append(symbol)
    return result
  }

  func verify(file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(symbols.count, expectedCalls, "fetch call count", file: file, line: line)
    XCTAssertTrue(
      symbols.allSatisfy { $0 == expectedSymbol },
      "expected only \(expectedSymbol), got \(symbols)", file: file, line: line)
  }
}

/// Returns a canned repository result and records which symbols were requested.
actor StubQuoteRepository: QuoteRepository {
  private let result: Result<CacheResult, QuoteError>
  private(set) var requestedSymbols: [String] = []

  init(result: Result<CacheResult, QuoteError>) {
    self.result = result
  }

  func find(for symbol: String) async -> Result<CacheResult, QuoteError> {
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

/// Records every event the code under test sends. `track` is synchronous, so this is a
/// lock-guarded class rather than an actor.
final class SpyAnalyticsTracker: AnalyticsTracker, @unchecked Sendable {
  private let lock = NSLock()
  private var recorded: [QuoteAnalyticsEvent] = []

  var events: [QuoteAnalyticsEvent] {
    lock.lock(); defer { lock.unlock() }
    return recorded
  }

  func track(_ event: QuoteAnalyticsEvent) {
    lock.lock(); defer { lock.unlock() }
    recorded.append(event)
  }
}

/// Dummy: fills a required parameter the test never looks at. No state, no assertions.
struct DummyAnalyticsTracker: AnalyticsTracker {
  func track(_ event: QuoteAnalyticsEvent) {}
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
