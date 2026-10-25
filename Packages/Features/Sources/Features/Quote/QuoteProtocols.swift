import Foundation

protocol QuoteRepository: Sendable {
    func find(for symbol: String) async -> Result<CacheResult, QuoteError>
}

protocol QuoteAPIClient: Sendable {
    func fetch(for symbol: String) async -> Result<Quote, QuoteError>
}

protocol QuoteCache: Sendable {
    func find(for symbol: String) async -> CachedQuote?
    func store(_ quote: Quote) async
}


protocol ACClockProtocol: Sendable {
  var current: Date { get }
}


protocol HttpClient: Sendable {
  func fetch(for request: URLRequest) async throws -> (Data, URLResponse)
}
