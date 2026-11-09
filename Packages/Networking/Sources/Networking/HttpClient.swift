import Foundation

/// Sends a request and returns the body of a successful (2xx) response.
/// Every failure is thrown as an `HttpError`.
public protocol HttpClient: Sendable {
  func send(_ request: URLRequest) async throws -> Data
}
