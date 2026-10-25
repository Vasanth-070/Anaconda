import XCTest
@testable import Features

final class InMemoryQuoteCacheTests: XCTestCase {
  private let ttl: TimeInterval = 120

  private func makeSUT() -> (cache: InMemoryQuoteCache, clock: FakeClock) {
    let clock = FakeClock()
    return (InMemoryQuoteCache(clock: clock, ttl: ttl), clock)
  }

  func test_find_onEmptyCache_returnsNil() async {
    let (cache, _) = makeSUT()

    let result = await cache.find(for: "AAPL")

    XCTAssertNil(result)
  }

  func test_find_withinTTL_returnsFreshQuote() async {
    let (cache, clock) = makeSUT()
    await cache.store(.sample(price: 150))

    clock.advance(by: ttl - 1)
    let result = await cache.find(for: "AAPL")

    XCTAssertEqual(result?.quote.price, 150)
    XCTAssertEqual(result?.isFresh, true)
  }

  func test_find_afterTTL_returnsStaleQuote() async {
    let (cache, clock) = makeSUT()
    await cache.store(.sample(price: 150))

    clock.advance(by: ttl + 1)
    let result = await cache.find(for: "AAPL")

    XCTAssertEqual(result?.quote.price, 150)
    XCTAssertEqual(result?.isFresh, false)
  }

  func test_store_sameSymbolTwice_replacesQuoteAndRestartsTTL() async {
    let (cache, clock) = makeSUT()
    await cache.store(.sample(price: 100))
    clock.advance(by: ttl + 1)

    await cache.store(.sample(price: 200))
    let result = await cache.find(for: "AAPL")

    XCTAssertEqual(result?.quote.price, 200)
    XCTAssertEqual(result?.isFresh, true)
  }

  func test_find_differentSymbol_returnsNil() async {
    let (cache, _) = makeSUT()
    await cache.store(.sample(symbol: "AAPL"))

    let result = await cache.find(for: "MSFT")

    XCTAssertNil(result)
  }
}
