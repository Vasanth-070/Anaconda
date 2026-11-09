import XCTest
import Persistence
@testable import Features

final class AcQuoteRepositoryTests: XCTestCase {
  private func makeSUT(
    cached: CachedValue<Quote>?,
    api: Result<Quote, QuoteError>
  ) -> (sut: AcQuoteRepository, api: StubAPIClient, cache: SpyCache) {
    let apiClient = StubAPIClient(result: api)
    let cache = SpyCache(entry: cached)
    return (AcQuoteRepository(api: apiClient, cache: cache), apiClient, cache)
  }

  func test_find_freshCacheHit_returnsHitWithoutCallingAPI() async {
    let (sut, api, cache) = makeSUT(
      cached: CachedValue(value: .sample(price: 100), isFresh: true),
      api: .success(.sample(price: 999))
    )

    let result = await sut.find(for: "AAPL")

    guard case .success(let value) = result else { return XCTFail("expected success, got \(result)") }
    XCTAssertEqual(value.data.price, 100)
    XCTAssertEqual(value.status, .hit)
    let calls = await api.callCount
    let stored = await cache.storedQuotes
    XCTAssertEqual(calls, 0)
    XCTAssertTrue(stored.isEmpty)
  }

  func test_find_cacheMiss_apiSuccess_returnsHitAndStoresQuote() async {
    let (sut, api, cache) = makeSUT(cached: nil, api: .success(.sample(price: 150)))

    let result = await sut.find(for: "AAPL")

    guard case .success(let value) = result else { return XCTFail("expected success, got \(result)") }
    XCTAssertEqual(value.data.price, 150)
    XCTAssertEqual(value.status, .hit)
    let symbols = await api.requestedSymbols
    let stored = await cache.storedQuotes
    XCTAssertEqual(symbols, ["AAPL"])
    XCTAssertEqual(stored.map(\.price), [150])
  }

  func test_find_staleCache_apiSuccess_returnsFreshQuoteAndRefreshesCache() async {
    let (sut, _, cache) = makeSUT(
      cached: CachedValue(value: .sample(price: 100), isFresh: false),
      api: .success(.sample(price: 150))
    )

    let result = await sut.find(for: "AAPL")

    guard case .success(let value) = result else { return XCTFail("expected success, got \(result)") }
    XCTAssertEqual(value.data.price, 150)
    XCTAssertEqual(value.status, .hit)
    let stored = await cache.storedQuotes
    XCTAssertEqual(stored.map(\.price), [150])
  }

  func test_find_staleCache_apiFailure_returnsStaleQuote() async {
    let (sut, _, cache) = makeSUT(
      cached: CachedValue(value: .sample(price: 100), isFresh: false),
      api: .failure(.connection)
    )

    let result = await sut.find(for: "AAPL")

    guard case .success(let value) = result else { return XCTFail("expected success, got \(result)") }
    XCTAssertEqual(value.data.price, 100)
    XCTAssertEqual(value.status, .stale)
    let stored = await cache.storedQuotes
    XCTAssertTrue(stored.isEmpty)
  }

  func test_find_staleCache_symbolNotFound_stillReturnsStaleQuote() async {
    let (sut, _, _) = makeSUT(
      cached: CachedValue(value: .sample(price: 100), isFresh: false),
      api: .failure(.symbolNotFound)
    )

    let result = await sut.find(for: "AAPL")

    guard case .success(let value) = result else { return XCTFail("expected success, got \(result)") }
    XCTAssertEqual(value.status, .stale)
  }

  func test_find_staleCache_unauthorized_returnsFailureInsteadOfStale() async {
    let (sut, _, _) = makeSUT(
      cached: CachedValue(value: .sample(price: 100), isFresh: false),
      api: .failure(.unauthorized)
    )

    let result = await sut.find(for: "AAPL")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .unauthorized)
  }

  func test_find_staleCache_cancelled_returnsCancelledInsteadOfStale() async {
    let (sut, _, _) = makeSUT(
      cached: CachedValue(value: .sample(price: 100), isFresh: false),
      api: .failure(.cancelled)
    )

    let result = await sut.find(for: "AAPL")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .cancelled)
  }

  func test_find_cacheMiss_apiFailure_returnsFailure() async {
    let (sut, _, cache) = makeSUT(cached: nil, api: .failure(.offline))

    let result = await sut.find(for: "AAPL")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .offline)
    let stored = await cache.storedQuotes
    XCTAssertTrue(stored.isEmpty)
  }

  /// Real cache + FakeClock: proves store-then-find works end to end, which SpyCache cannot.
  func test_find_twiceWithinTTL_secondCallServedFromCacheWithoutAPI() async {
    let api = StubAPIClient(result: .success(.sample(price: 150)))
    let cache = AcCache<Quote>(clock: FakeClock())
    let sut = AcQuoteRepository(api: api, cache: cache)

    _ = await sut.find(for: "AAPL")
    let second = await sut.find(for: "AAPL")

    guard case .success(let value) = second else { return XCTFail("expected success, got \(second)") }
    XCTAssertEqual(value.data.price, 150)
    XCTAssertEqual(value.status, .hit)
    let calls = await api.callCount
    XCTAssertEqual(calls, 1)
  }
}
