import XCTest
@testable import Features

/// Returns a canned repository result and records which symbols were requested.
private actor StubRepository: QuoteRepository {
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

@MainActor
final class QuoteViewModelTests: XCTestCase {
  private func makeSUT(
    result: Result<CacheResult, QuoteError>
  ) -> (sut: QuoteViewModel, repo: StubRepository) {
    let repo = StubRepository(result: result)
    return (QuoteViewModel(repository: repo), repo)
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
}
