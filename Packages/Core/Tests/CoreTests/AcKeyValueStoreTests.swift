import XCTest
@testable import Core

final class AcKeyValueStoreTests: XCTestCase {
  private var suiteName: String!
  private var sut: AcKeyValueStore!

  override func setUp() {
    super.setUp()
    suiteName = "AcKeyValueStoreTests-\(UUID().uuidString)"
    sut = AcKeyValueStore(defaults: UserDefaults(suiteName: suiteName)!)
  }

  override func tearDown() {
    UserDefaults().removePersistentDomain(forName: suiteName)
    sut = nil
    suiteName = nil
    super.tearDown()
  }

  func test_string_missingKey_returnsNil() {
    XCTAssertNil(sut.string(forKey: "missing"))
  }

  func test_set_thenString_returnsStoredValue() {
    sut.set("AAPL", forKey: "lastSymbol")

    XCTAssertEqual(sut.string(forKey: "lastSymbol"), "AAPL")
  }

  func test_set_sameKeyTwice_overwritesValue() {
    sut.set("AAPL", forKey: "lastSymbol")
    sut.set("MSFT", forKey: "lastSymbol")

    XCTAssertEqual(sut.string(forKey: "lastSymbol"), "MSFT")
  }

  func test_set_nil_removesValue() {
    sut.set("AAPL", forKey: "lastSymbol")

    sut.set(nil, forKey: "lastSymbol")

    XCTAssertNil(sut.string(forKey: "lastSymbol"))
  }

  func test_set_doesNotLeakIntoOtherKeys() {
    sut.set("AAPL", forKey: "a")

    XCTAssertNil(sut.string(forKey: "b"))
  }
}
