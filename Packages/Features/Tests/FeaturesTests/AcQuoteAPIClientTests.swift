import XCTest
@testable import Features

/// Returns a canned HTTP response (or throws) and records the requests it received.
private actor StubHttpClient: HttpClient {
  enum Outcome {
    case response(Data, statusCode: Int)
    case failure(Error)
  }

  private let outcome: Outcome
  private(set) var requests: [URLRequest] = []

  init(outcome: Outcome) {
    self.outcome = outcome
  }

  func fetch(for request: URLRequest) async throws -> (Data, URLResponse) {
    requests.append(request)
    switch outcome {
    case .response(let data, let statusCode):
      let response = HTTPURLResponse(
        url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil
      )!
      return (data, response)
    case .failure(let error):
      throw error
    }
  }
}

final class AcQuoteAPIClientTests: XCTestCase {
  private let validJSON = Data(#"{"symbol":"AAPL","price":150.5,"change":1.2}"#.utf8)

  private func makeSUT(outcome: StubHttpClient.Outcome) -> (sut: AcQuoteAPIClient, http: StubHttpClient) {
    let http = StubHttpClient(outcome: outcome)
    return (AcQuoteAPIClient(session: http), http)
  }

  func test_fetch_status200_validJSON_returnsDecodedQuote() async {
    let (sut, _) = makeSUT(outcome: .response(validJSON, statusCode: 200))

    let result = await sut.fetch(for: "AAPL")

    guard case .success(let quote) = result else { return XCTFail("expected success, got \(result)") }
    XCTAssertEqual(quote.symbol, "AAPL")
    XCTAssertEqual(quote.price, 150.5)
    XCTAssertEqual(quote.change, 1.2)
  }

  func test_fetch_status200_invalidJSON_returnsDecodingError() async {
    let (sut, _) = makeSUT(outcome: .response(Data("not json".utf8), statusCode: 200))

    let result = await sut.fetch(for: "AAPL")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .decoding)
  }

  func test_fetch_status401_returnsUnauthorized() async {
    let (sut, _) = makeSUT(outcome: .response(Data(), statusCode: 401))

    let result = await sut.fetch(for: "AAPL")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .unauthorized)
  }

  func test_fetch_status404_returnsSymbolNotFound() async {
    let (sut, _) = makeSUT(outcome: .response(Data(), statusCode: 404))

    let result = await sut.fetch(for: "NOPE")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .symbolNotFound)
  }

  func test_fetch_status500_returnsUnknown() async {
    let (sut, _) = makeSUT(outcome: .response(Data(), statusCode: 500))

    let result = await sut.fetch(for: "AAPL")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .unknown)
  }

  func test_fetch_notConnectedToInternet_returnsOffline() async {
    let (sut, _) = makeSUT(outcome: .failure(URLError(.notConnectedToInternet)))

    let result = await sut.fetch(for: "AAPL")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .offline)
  }

  func test_fetch_timeout_returnsConnectionError() async {
    let (sut, _) = makeSUT(outcome: .failure(URLError(.timedOut)))

    let result = await sut.fetch(for: "AAPL")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .connection)
  }

  func test_fetch_nonURLError_returnsUnknown() async {
    struct Boom: Error {}
    let (sut, _) = makeSUT(outcome: .failure(Boom()))

    let result = await sut.fetch(for: "AAPL")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .unknown)
  }

  func test_fetch_buildsGETRequestWithSymbolAsCodeQuery() async throws {
    let (sut, http) = makeSUT(outcome: .response(validJSON, statusCode: 200))

    _ = await sut.fetch(for: "AAPL")

    let requests = await http.requests
    let request = try XCTUnwrap(requests.first)
    let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
    XCTAssertEqual(requests.count, 1)
    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(components.queryItems, [URLQueryItem(name: "code", value: "AAPL")])
  }
}
