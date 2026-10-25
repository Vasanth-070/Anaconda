//
//  QuoteRepository.swift
//  Features
//
//  Created by Vasanth Gentela on 10/25/26.
//

import Foundation

final class AcQuoteRepository: QuoteRepository {
  private let api: QuoteAPIClient
  private let cache: QuoteCache

  init(api: QuoteAPIClient, cache: QuoteCache) {
    self.api = api
    self.cache = cache
  }

  func find(for symbol: String) async -> Result<CacheResult, QuoteError> {
    let cached = await cache.find(for: symbol)
    if let cached, cached.isFresh {
      return .success(CacheResult(data: cached.quote, status: .hit))
    }

    switch await api.fetch(for: symbol) {
    case .success(let quote):
      await cache.store(quote)
      return .success(CacheResult(data: quote, status: .hit))
    case .failure(let error):
      // Serve the stale quote on any failure except auth, which must surface so the user re-logs in.
      if let cached, error != .unauthorized {
        return .success(CacheResult(data: cached.quote, status: .stale))
      }
      return .failure(error)
    }
  }
}

final class AcQuoteAPIClient: QuoteAPIClient {
  let endpoint = "/quote"
  let host = "https://anaconda.com/"
  let session: HttpClient

  init(session: HttpClient) {
    self.session = session
  }
  
  func fetch(for symbol: String) async -> Result<Quote, QuoteError> {
    var components = URLComponents(string: host + endpoint)
    components?.queryItems = [URLQueryItem(name: "code", value: symbol)]

    guard let url = components?.url else { return .failure(.unknown) }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"          // GET is the default, so this is optional
    request.timeoutInterval = 10
    do {
      let (data, response) = try await session.fetch(for: request)

      guard let http = response as? HTTPURLResponse else {
        return .failure(.unknown)
      }

      switch http.statusCode {
      case 200..<300:
        do {
          return .success(try JSONDecoder().decode(Quote.self, from: data))
        } catch {
          return .failure(.decoding)
        }
      case 401, 403:
        return .failure(.unauthorized)
      case 404:
        return .failure(.symbolNotFound)
      default:
        return .failure(.unknown)
      }
    } catch let error as URLError {
      switch error.code {
      case .notConnectedToInternet, .dataNotAllowed:
        return .failure(.offline)
      default:
        return .failure(.connection)
      }
    } catch {
      return .failure(.unknown)
    }
  }
  
  
}
