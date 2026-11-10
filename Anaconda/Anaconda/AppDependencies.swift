import Core
import Features
import Foundation
import Networking
import Persistence

/// Composition root: the one place that picks concrete types and wires them together.
/// Everything else asks for protocols in its `init`. Tests/previews build their own instance.
struct AppDependencies {
  let clock: ClockProtocol
  let uuid: UUIDGenerator
  let store: KeyValueStore
  let http: HttpClient
  let analytics: AnalyticsTracker
  let baseURL: URL  // backend host, shared by every feature's API client
  let quoteCache: any Cache<Quote>  // shared: one cache for the whole app

  /// Real services. PLACEHOLDER base URL until a quote provider is chosen.
  static let live: AppDependencies = make(
    http: AcHttpClient(),
    baseURL: URL(string: "https://api.example.com")!
  )

  /// Same graph as `live`, but HTTP is faked: works offline, no provider or API key needed.
  static let dev: AppDependencies = make(
    http: DevHttpClient(),
    baseURL: URL(string: "https://dev.invalid")!
  )

  private static func make(http: HttpClient, baseURL: URL) -> AppDependencies {
    let clock = AcClock()
    return AppDependencies(
      clock: clock,
      uuid: AcUUIDGenerator(),
      store: AcKeyValueStore(),
      http: http,
      analytics: ConsoleAnalyticsTracker(),
      baseURL: baseURL,
      quoteCache: AcCache<Quote>(clock: clock)
    )
  }

  /// Per-screen object: built on demand from the shared dependencies.
  @MainActor
  func makeQuoteViewModel() -> QuoteViewModel {
    let api = AcQuoteAPIClient(baseURL: baseURL, http: http)
    let repository = AcQuoteRepository(api: api, cache: quoteCache)
    return QuoteViewModel(repository: repository, analytics: analytics)
  }
}
