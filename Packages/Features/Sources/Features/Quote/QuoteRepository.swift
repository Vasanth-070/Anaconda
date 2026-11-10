//
//  QuoteRepository.swift
//  Features
//
//  Created by Vasanth Gentela on 10/25/26.
//

import Foundation
import Networking
import Persistence

public final class AcQuoteRepository: QuoteRepository {
  private let api: QuoteAPIClient
  private let cache: any Cache<Quote>

  public init(api: QuoteAPIClient, cache: any Cache<Quote>) {
    self.api = api
    self.cache = cache
  }

  public func find(for symbol: String) async -> Result<CacheResult, QuoteError> {
    let cached = await cache.find(for: symbol)
    if let cached, cached.isFresh {
      return .success(CacheResult(data: cached.value, status: .hit))
    }

    switch await api.fetch(for: symbol) {
    case .success(let quote):
      await cache.store(quote, for: symbol)
      return .success(CacheResult(data: quote, status: .hit))
    case .failure(let error):
      // Serve the stale quote on any failure except:
      // - auth, which must surface so the user re-logs in
      // - cancellation, because the caller left and nobody should be shown a result
      if let cached, error != .unauthorized, error != .cancelled {
        return .success(CacheResult(data: cached.value, status: .stale))
      }
      return .failure(error)
    }
  }
}

public final class AcQuoteAPIClient: QuoteAPIClient {
  private let baseURL: URL
  let http: HttpClient

  public init(baseURL: URL, http: HttpClient) {
    self.baseURL = baseURL
    self.http = http
  }

  public func fetch(for symbol: String) async -> Result<Quote, QuoteError> {
    var components = URLComponents(url: baseURL.appending(path: "quote"), resolvingAgainstBaseURL: false)
    components?.queryItems = [URLQueryItem(name: "code", value: symbol)]

    guard let url = components?.url else { return .failure(.unknown) }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = 10

    do {
      let data = try await http.send(request)
      return .success(try JSONDecoder().decode(Quote.self, from: data))
    } catch let error as HttpError {
      return .failure(Self.map(error))
    } catch {
      return .failure(.decoding)
    }
  }

  private static func map(_ error: HttpError) -> QuoteError {
    switch error {
    case .offline: .offline
    case .cancelled: .cancelled
    case .connection: .connection
    case .unauthorized: .unauthorized
    case .notFound: .symbolNotFound
    case .status, .invalidResponse: .unknown
    }
  }
}
