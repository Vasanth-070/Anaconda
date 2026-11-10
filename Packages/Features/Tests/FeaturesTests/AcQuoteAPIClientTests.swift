import XCTest
import Networking
@testable import Features

/// Returns a canned body (or throws an HttpError) and records the requests it received.
private actor StubHttpClient: HttpClient {
  enum Outcome {
    case body(Data)
    case failure(HttpError)
  }

  private let outcome: Outcome
  private(set) var requests: [URLRequest] = []

  init(outcome: Outcome) {
    self.outcome = outcome
  }

  func send(_ request: URLRequest) async throws -> Data {
    requests.append(request)
    switch outcome {
    case .body(let data): return data
    case .failure(let error): throw error
    }
  }
}

final class AcQuoteAPIClientTests: XCTestCase {
  private let validJSON = Data(#"{"symbol":"AAPL","price":150.5,"change":1.2}"#.utf8)

  private func makeSUT(outcome: StubHttpClient.Outcome) -> (sut: AcQuoteAPIClient, http: StubHttpClient) {
    let http = StubHttpClient(outcome: outcome)
    return (AcQuoteAPIClient(baseURL: URL(string: "https://example.test")!, http: http), http)
  }

  func test_fetch_status200_validJSON_returnsDecodedQuote() async {
    let (sut, _) = makeSUT(outcome: .body(validJSON))

    let result = await sut.fetch(for: "AAPL")

    guard case .success(let quote) = result else { return XCTFail("expected success, got \(result)") }
    XCTAssertEqual(quote.symbol, "AAPL")
    XCTAssertEqual(quote.price, 150.5)
    XCTAssertEqual(quote.change, 1.2)
  }

  func test_fetch_invalidJSON_returnsDecodingError() async {
    let (sut, _) = makeSUT(outcome: .body(Data("not json".utf8)))

    let result = await sut.fetch(for: "AAPL")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .decoding)
  }

  func test_fetch_emptyBody_returnsDecodingError() async {
    let (sut, _) = makeSUT(outcome: .body(Data()))

    let result = await sut.fetch(for: "AAPL")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .decoding)
  }

  func test_fetch_unauthorized_returnsUnauthorized() async {
    let (sut, _) = makeSUT(outcome: .failure(.unauthorized))

    let result = await sut.fetch(for: "AAPL")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .unauthorized)
  }

  func test_fetch_notFound_returnsSymbolNotFound() async {
    let (sut, _) = makeSUT(outcome: .failure(.notFound))

    let result = await sut.fetch(for: "NOPE")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .symbolNotFound)
  }

  func test_fetch_serverStatus_returnsUnknown() async {
    let (sut, _) = makeSUT(outcome: .failure(.status(500)))

    let result = await sut.fetch(for: "AAPL")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .unknown)
  }

  func test_fetch_offline_returnsOffline() async {
    let (sut, _) = makeSUT(outcome: .failure(.offline))

    let result = await sut.fetch(for: "AAPL")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .offline)
  }

  func test_fetch_connection_returnsConnectionError() async {
    let (sut, _) = makeSUT(outcome: .failure(.connection))

    let result = await sut.fetch(for: "AAPL")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .connection)
  }

  func test_fetch_cancelled_returnsCancelled() async {
    let (sut, _) = makeSUT(outcome: .failure(.cancelled))

    let result = await sut.fetch(for: "AAPL")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .cancelled)
  }

  func test_fetch_invalidResponse_returnsUnknown() async {
    let (sut, _) = makeSUT(outcome: .failure(.invalidResponse))

    let result = await sut.fetch(for: "AAPL")

    guard case .failure(let error) = result else { return XCTFail("expected failure, got \(result)") }
    XCTAssertEqual(error, .unknown)
  }

  func test_fetch_buildsGETRequestWithSymbolAsCodeQuery() async throws {
    let (sut, http) = makeSUT(outcome: .body(validJSON))

    _ = await sut.fetch(for: "AAPL")

    let requests = await http.requests
    let request = try XCTUnwrap(requests.first)
    let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
    XCTAssertEqual(requests.count, 1)
    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.url?.absoluteString, "https://example.test/quote?code=AAPL")
    XCTAssertEqual(components.queryItems, [URLQueryItem(name: "code", value: "AAPL")])
  }
}
