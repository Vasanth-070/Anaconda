import Foundation

/// Production `HttpClient`: performs the request on a URLSession and maps
/// status codes and URLErrors to `HttpError` in one place.
public final class AcHttpClient: HttpClient {
  private let urlSession: URLSession

  public init(urlSession: URLSession = .shared) {
    self.urlSession = urlSession
  }

  public func send(_ request: URLRequest) async throws -> Data {
    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await urlSession.data(for: request)
    } catch let error as URLError {
      throw Self.map(error)
    } catch {
      throw HttpError.connection
    }

    guard let http = response as? HTTPURLResponse else { throw HttpError.invalidResponse }

    switch http.statusCode {
    case 200..<300: return data
    case 401, 403: throw HttpError.unauthorized
    case 404: throw HttpError.notFound
    default: throw HttpError.status(http.statusCode)
    }
  }

  private static func map(_ error: URLError) -> HttpError {
    switch error.code {
    case .notConnectedToInternet, .dataNotAllowed: .offline
    case .cancelled: .cancelled
    default: .connection
    }
  }
}
