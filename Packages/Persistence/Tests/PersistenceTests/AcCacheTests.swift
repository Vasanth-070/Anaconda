import XCTest
import Core
@testable import Persistence

/// One clock the test can move forward between a store and a read.
private final class FakeClock: ClockProtocol, @unchecked Sendable {
  private let lock = NSLock()
  private var now = Date(timeIntervalSince1970: 1_000_000)

  var current: Date {
    lock.lock(); defer { lock.unlock() }
    return now
  }

  func advance(by seconds: TimeInterval) {
    lock.lock(); defer { lock.unlock() }
    now = now.addingTimeInterval(seconds)
  }
}

final class AcCacheTests: XCTestCase {
  private let ttl: TimeInterval = 120

  private func makeSUT() -> (cache: AcCache<String>, clock: FakeClock) {
    let clock = FakeClock()
    return (AcCache(clock: clock, ttl: ttl), clock)
  }

  func test_find_onEmptyCache_returnsNil() async {
    let (cache, _) = makeSUT()

    let result = await cache.find(for: "AAPL")

    XCTAssertNil(result)
  }

  func test_find_withinTTL_returnsFreshValue() async {
    let (cache, clock) = makeSUT()
    await cache.store("150", for: "AAPL")

    clock.advance(by: ttl - 1)
    let result = await cache.find(for: "AAPL")

    XCTAssertEqual(result?.value, "150")
    XCTAssertEqual(result?.isFresh, true)
  }

  func test_find_afterTTL_returnsStaleValue() async {
    let (cache, clock) = makeSUT()
    await cache.store("150", for: "AAPL")

    clock.advance(by: ttl + 1)
    let result = await cache.find(for: "AAPL")

    XCTAssertEqual(result?.value, "150")
    XCTAssertEqual(result?.isFresh, false)
  }

  func test_store_sameKeyTwice_replacesValueAndRestartsTTL() async {
    let (cache, clock) = makeSUT()
    await cache.store("100", for: "AAPL")
    clock.advance(by: ttl + 1)

    await cache.store("200", for: "AAPL")
    let result = await cache.find(for: "AAPL")

    XCTAssertEqual(result?.value, "200")
    XCTAssertEqual(result?.isFresh, true)
  }

  func test_find_differentKey_returnsNil() async {
    let (cache, _) = makeSUT()
    await cache.store("100", for: "AAPL")

    let result = await cache.find(for: "MSFT")

    XCTAssertNil(result)
  }
}
