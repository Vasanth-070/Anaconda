import Foundation
import Networking

/// Development `HttpClient`: answers quote requests with canned JSON, no network.
/// Echoes the requested `code` back as the symbol so any ticker works.
struct DevHttpClient: HttpClient {
  var latency: Duration = .milliseconds(500)

  func send(_ request: URLRequest) async throws -> Data {
    try? await Task.sleep(for: latency)
    let symbol = request.url
      .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
      .queryItems?.first(where: { $0.name == "code" })?.value ?? "UNKNOWN"
    return Data(#"{"symbol":"\#(symbol)","price":150.25,"change":1.2}"#.utf8)
  }
}
