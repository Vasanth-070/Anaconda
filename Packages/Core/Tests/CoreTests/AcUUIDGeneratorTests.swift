import XCTest
@testable import Core

final class AcUUIDGeneratorTests: XCTestCase {
  func test_make_calledRepeatedly_returnsUniqueIds() {
    let sut = AcUUIDGenerator()

    let ids = (0..<1_000).map { _ in sut.make() }

    XCTAssertEqual(Set(ids).count, ids.count)
  }
}
