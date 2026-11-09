import Foundation

protocol QuoteRepository: Sendable {
    func find(for symbol: String) async -> Result<CacheResult, QuoteError>
}

protocol QuoteAPIClient: Sendable {
    func fetch(for symbol: String) async -> Result<Quote, QuoteError>
}


