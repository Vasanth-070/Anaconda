import Foundation

struct Quote: Decodable {
    let symbol: String
    let price: Double
    let change: Double
}

enum QuoteError: Error {
    case offline, connection, symbolNotFound, decoding, unauthorized, cancelled, unknown
}

enum CacheStatus {
    case hit, stale
}

struct CacheResult {
    let data: Quote
    let status: CacheStatus
}

