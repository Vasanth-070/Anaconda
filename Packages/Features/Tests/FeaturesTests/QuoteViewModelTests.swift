import XCTest
@testable import Features

@MainActor
final class QuoteViewModelTests: XCTestCase {
  private func makeSUT(
    result: Result<CacheResult, QuoteError>,
    analytics: AnalyticsTracker = DummyAnalyticsTracker()
  ) -> (sut: QuoteViewModel, repo: StubQuoteRepository) {
    let repo = StubQuoteRepository(result: result)
    return (QuoteViewModel(repository: repo, analytics: analytics), repo)
  }

  func test_init_startsIdle() {
    let (sut, _) = makeSUT(result: .failure(.unknown))

    guard case .idle = sut.state else { return XCTFail("expected idle, got \(sut.state)") }
  }

  func test_load_freshResult_setsLoadedState() async {
    let (sut, _) = makeSUT(result: .success(CacheResult(data: .sample(price: 150), status: .hit)))

    await sut.load(symbol: "AAPL")

    guard case .loaded(let quote) = sut.state else { return XCTFail("expected loaded, got \(sut.state)") }
    XCTAssertEqual(quote.price, 150)
  }

  func test_load_staleResult_setsStaleState() async {
    let (sut, _) = makeSUT(result: .success(CacheResult(data: .sample(price: 100), status: .stale)))

    await sut.load(symbol: "AAPL")

    guard case .stale(let quote) = sut.state else { return XCTFail("expected stale, got \(sut.state)") }
    XCTAssertEqual(quote.price, 100)
  }

  func test_load_failure_setsFailedStateWithError() async {
    let (sut, _) = makeSUT(result: .failure(.unauthorized))

    await sut.load(symbol: "AAPL")

    guard case .failed(let error) = sut.state else { return XCTFail("expected failed, got \(sut.state)") }
    XCTAssertEqual(error, .unauthorized)
  }

  func test_load_asksRepositoryForRequestedSymbol() async {
    let (sut, repo) = makeSUT(result: .failure(.unknown))

    await sut.load(symbol: "MSFT")

    let symbols = await repo.requestedSymbols
    XCTAssertEqual(symbols, ["MSFT"])
  }

  func test_load_freshResult_tracksLoadedEvent() async {
    let analytics = SpyAnalyticsTracker()
    let (sut, _) = makeSUT(result: .success(CacheResult(data: .sample(), status: .hit)), analytics: analytics)

    await sut.load(symbol: "AAPL")

    XCTAssertEqual(analytics.events, [.loaded(symbol: "AAPL")])
  }

  func test_load_staleResult_tracksStaleEvent() async {
    let analytics = SpyAnalyticsTracker()
    let (sut, _) = makeSUT(result: .success(CacheResult(data: .sample(), status: .stale)), analytics: analytics)

    await sut.load(symbol: "AAPL")

    XCTAssertEqual(analytics.events, [.stale(symbol: "AAPL")])
  }

  func test_load_failure_tracksFailedEventWithError() async {
    let analytics = SpyAnalyticsTracker()
    let (sut, _) = makeSUT(result: .failure(.offline), analytics: analytics)

    await sut.load(symbol: "AAPL")

    XCTAssertEqual(analytics.events, [.failed(symbol: "AAPL", error: .offline)])
  }
}
