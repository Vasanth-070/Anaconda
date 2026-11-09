import Foundation

/// Intercepts every request made through a URLSession that registers it, so tests
/// run the real URLSession stack without touching the network.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
  enum Behavior {
    case respond(statusCode: Int, body: Data)
    case fail(URLError.Code)
    case hang            // never completes; used to test cancellation
  }

  private static let lock = NSLock()
  nonisolated(unsafe) private static var _behavior: Behavior = .hang
  nonisolated(unsafe) private static var _requests: [URLRequest] = []

  static var behavior: Behavior {
    get { lock.withLock { _behavior } }
    set { lock.withLock { _behavior = newValue } }
  }

  static var requests: [URLRequest] { lock.withLock { _requests } }

  static func reset() {
    lock.withLock {
      _behavior = .hang
      _requests = []
    }
  }

  /// A URLSession whose only protocol is this stub.
  static func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: config)
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.lock.withLock { Self._requests.append(request) }

    switch Self.behavior {
    case .respond(let statusCode, let body):
      let response = HTTPURLResponse(
        url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil
      )!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: body)
      client?.urlProtocolDidFinishLoading(self)
    case .fail(let code):
      client?.urlProtocol(self, didFailWithError: URLError(code))
    case .hang:
      break
    }
  }

  override func stopLoading() {}
}
