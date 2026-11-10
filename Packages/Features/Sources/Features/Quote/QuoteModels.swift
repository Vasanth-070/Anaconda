import Foundation

public struct Quote: Decodable, Sendable {
    public let symbol: String
    public let price: Double
    public let change: Double
}

public enum QuoteError: Error, Equatable {
    case offline, connection, symbolNotFound, decoding, unauthorized, cancelled, unknown
}

public enum CacheStatus: Sendable {
    case hit, stale
}

public struct CacheResult: Sendable {
    public let data: Quote
    public let status: CacheStatus
}

