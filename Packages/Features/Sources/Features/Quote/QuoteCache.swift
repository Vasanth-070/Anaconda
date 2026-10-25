import Foundation

/// Cache that stamps entries with its own injected clock and decides freshness itself.
actor InMemoryQuoteCache: QuoteCache {
  private struct Entry {
    let quote: Quote
    let storedAt: Date
  }

  private var entries: [String: Entry] = [:]
  private let clock: ACClockProtocol
  private let ttl: TimeInterval

  init(clock: ACClockProtocol, ttl: TimeInterval = 120) {
    self.clock = clock
    self.ttl = ttl
  }

  func find(for symbol: String) -> CachedQuote? {
    guard let entry = entries[symbol] else { return nil }
    let age = clock.current.timeIntervalSince(entry.storedAt)
    return CachedQuote(quote: entry.quote, isFresh: age < ttl)
  }

  func store(_ quote: Quote) {
    entries[quote.symbol] = Entry(quote: quote, storedAt: clock.current)
  }
}
