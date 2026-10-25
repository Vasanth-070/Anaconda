import Foundation

final class ACClientSession: HttpClient {
  let clientId: String
  let authToken: String
  private let urlSession: URLSession

  init(clientId: String, authToken: String, urlSession: URLSession = .shared) {
    self.clientId = clientId
    self.authToken = authToken
    self.urlSession = urlSession
  }

  func fetch(for request: URLRequest) async throws -> (Data, URLResponse) {
    try await urlSession.data(for: request)
  }
}
