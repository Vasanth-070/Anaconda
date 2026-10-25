import Foundation

struct Quote: Decodable {
    let symbol: String
    let price: Double
    let change: Double
}

enum QuoteError: Error {
    case offline, connection, symbolNotFound, decoding, unauthorized, unknown
}

/// What the cache hands back: the quote plus whether it is still within its TTL.
struct CachedQuote {
    let quote: Quote
    let isFresh: Bool
}

enum CacheStatus {
    case hit, stale
}

struct CacheResult {
    let data: Quote
    let status: CacheStatus
}


struct ACClock: ACClockProtocol {
  var current: Date {
    Date()
  }
}
