import XCTest
import Core
import Features
import Networking
import Persistence
@testable import Anaconda

private struct FixedClock: ClockProtocol {
  var current: Date { Date(timeIntervalSince1970: 1_000_000) }
}

private struct FixedUUIDGenerator: UUIDGenerator {
  func make() -> UUID { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! }
}

private final class MemoryStore: KeyValueStore, @unchecked Sendable {
  private let lock = NSLock()
  private var values: [String: String] = [:]

  func string(forKey key: String) -> String? {
    lock.lock(); defer { lock.unlock() }
    return values[key]
  }

  func set(_ value: String?, forKey key: String) {
    lock.lock(); defer { lock.unlock() }
    values[key] = value
  }
}

private struct StubHttpClient: HttpClient {
  let body: Data
  func send(_ request: URLRequest) async throws -> Data { body }
}

private final class RecordingAnalytics: AnalyticsTracker, @unchecked Sendable {
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

/// Proves the composition root is swappable: the whole graph runs on fakes, no network.
@MainActor
final class AppDependenciesTests: XCTestCase {
  func test_makeQuoteViewModel_usesInjectedDependencies() async {
    let clock = FixedClock()
    let analytics = RecordingAnalytics()
    let json = Data(#"{"symbol":"AAPL","price":150,"change":1}"#.utf8)
    let deps = AppDependencies(
      clock: clock,
      uuid: FixedUUIDGenerator(),
      store: MemoryStore(),
      http: StubHttpClient(body: json),
      analytics: analytics,
      baseURL: URL(string: "https://example.test")!,
      quoteCache: AcCache<Quote>(clock: clock)
    )

    let viewModel = deps.makeQuoteViewModel()
    await viewModel.load(symbol: "AAPL")

    guard case .loaded(let quote) = viewModel.state else {
      return XCTFail("expected loaded, got \(viewModel.state)")
    }
    XCTAssertEqual(quote.price, 150)
    XCTAssertEqual(analytics.events, [.loaded(symbol: "AAPL")])
  }

  func test_makeQuoteViewModel_twoViewModelsShareOneCache() async {
    let clock = FixedClock()
    let json = Data(#"{"symbol":"AAPL","price":150,"change":1}"#.utf8)
    let deps = AppDependencies(
      clock: clock,
      uuid: FixedUUIDGenerator(),
      store: MemoryStore(),
      http: StubHttpClient(body: json),
      analytics: RecordingAnalytics(),
      baseURL: URL(string: "https://example.test")!,
      quoteCache: AcCache<Quote>(clock: clock)
    )

    await deps.makeQuoteViewModel().load(symbol: "AAPL")
    let cached = await deps.quoteCache.find(for: "AAPL")

    XCTAssertEqual(cached?.value.price, 150)
    XCTAssertEqual(cached?.isFresh, true)
  }
}
