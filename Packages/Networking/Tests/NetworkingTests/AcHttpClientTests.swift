import XCTest
@testable import Networking

/// Runs the real AcHttpClient over a real URLSession, with the network replaced by StubURLProtocol.
final class AcHttpClientTests: XCTestCase {
  private let request = URLRequest(url: URL(string: "https://example.com/quote")!)

  override func setUp() {
    super.setUp()
    StubURLProtocol.reset()
  }

  override func tearDown() {
    StubURLProtocol.reset()
    super.tearDown()
  }

  private func makeSUT() -> AcHttpClient {
    AcHttpClient(urlSession: StubURLProtocol.makeSession())
  }

  /// Waits until the stub has received the request, so we cancel mid-flight, not before it starts.
  private func waitUntilRequestStarts() async throws {
    for _ in 0..<100 {
      if !StubURLProtocol.requests.isEmpty { return }
      try await Task.sleep(for: .milliseconds(10))
    }
    XCTFail("request never reached the stub")
  }

  private func assertSendThrows(_ expected: HttpError, file: StaticString = #filePath, line: UInt = #line) async {
    do {
      _ = try await makeSUT().send(request)
      XCTFail("expected \(expected), but send returned", file: file, line: line)
    } catch {
      XCTAssertEqual(error as? HttpError, expected, file: file, line: line)
    }
  }

  func test_send_status200_returnsBody() async throws {
    let body = Data("hello".utf8)
    StubURLProtocol.behavior = .respond(statusCode: 200, body: body)

    let data = try await makeSUT().send(request)

    XCTAssertEqual(data, body)
  }

  func test_send_status200_emptyBody_returnsEmptyData() async throws {
    StubURLProtocol.behavior = .respond(statusCode: 200, body: Data())

    let data = try await makeSUT().send(request)

    XCTAssertTrue(data.isEmpty)
  }

  func test_send_status401_throwsUnauthorized() async {
    StubURLProtocol.behavior = .respond(statusCode: 401, body: Data())
    await assertSendThrows(.unauthorized)
  }

  func test_send_status403_throwsUnauthorized() async {
    StubURLProtocol.behavior = .respond(statusCode: 403, body: Data())
    await assertSendThrows(.unauthorized)
  }

  func test_send_status404_throwsNotFound() async {
    StubURLProtocol.behavior = .respond(statusCode: 404, body: Data())
    await assertSendThrows(.notFound)
  }

  func test_send_status500_throwsStatus() async {
    StubURLProtocol.behavior = .respond(statusCode: 500, body: Data())
    await assertSendThrows(.status(500))
  }

  func test_send_notConnectedToInternet_throwsOffline() async {
    StubURLProtocol.behavior = .fail(.notConnectedToInternet)
    await assertSendThrows(.offline)
  }

  func test_send_timeout_throwsConnection() async {
    StubURLProtocol.behavior = .fail(.timedOut)
    await assertSendThrows(.connection)
  }

  func test_send_cancelledWhileInFlight_throwsCancelled() async throws {
    StubURLProtocol.behavior = .hang
    let sut = makeSUT()
    let request = self.request

    let task = Task { try await sut.send(request) }
    try await waitUntilRequestStarts()
    task.cancel()

    do {
      _ = try await task.value
      XCTFail("expected HttpError.cancelled, but send returned")
    } catch {
      XCTAssertEqual(error as? HttpError, .cancelled)
    }
  }
}
