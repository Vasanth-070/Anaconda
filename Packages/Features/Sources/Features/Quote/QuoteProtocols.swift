import Foundation

public protocol QuoteRepository: Sendable {
    func find(for symbol: String) async -> Result<CacheResult, QuoteError>
}

public protocol QuoteAPIClient: Sendable {
    func fetch(for symbol: String) async -> Result<Quote, QuoteError>
}

