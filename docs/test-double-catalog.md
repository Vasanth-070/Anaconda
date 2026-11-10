# Test-double catalog

All examples are from this repo (`Packages/Features/Tests/FeaturesTests/QuoteTestDoubles.swift` unless noted).

| Double | Purpose | Verifies |
|---|---|---|
| Dummy | Fills a required parameter | Nothing |
| Stub | Returns canned answers | State (what the code did with the answer) |
| Spy | Records how it was used | Behaviour, asserted afterwards by the test |
| Mock | Holds the expectation and judges it | Behaviour, asserted by the double |
| Fake | Working lightweight implementation | State, end to end |

## Dummy: `DummyAnalyticsTracker`

```swift
struct DummyAnalyticsTracker: AnalyticsTracker {
  func track(_ event: QuoteAnalyticsEvent) {}
}
```

**Why:** `QuoteViewModel` requires an `AnalyticsTracker`, but the state tests don't care about analytics. A dummy keeps those tests free of noise: `makeSUT` defaults to it. If a test ever needs to look at the tracker, it is not a dummy any more.

## Stub: `StubQuoteRepository`

```swift
actor StubQuoteRepository: QuoteRepository {
  private let result: Result<CacheResult, QuoteError>
  func find(for symbol: String) async -> Result<CacheResult, QuoteError> { result }
}
```

**Why:** the view-model tests need the repository to answer "fresh", "stale" or "failed" on demand. The test then asserts the view model's **state**. The stub has no opinion on whether it was called correctly. (This one also records `requestedSymbols`, which makes it a stub with a spy attached.)

## Spy: `SpyAnalyticsTracker`

```swift
final class SpyAnalyticsTracker: AnalyticsTracker, @unchecked Sendable {
  var events: [QuoteAnalyticsEvent] { ... }   // lock-guarded
  func track(_ event: QuoteAnalyticsEvent) { /* append */ }
}
```

**Why:** the analytics event is a side effect with no return value, so the only way to check it is to record it and look afterwards: `XCTAssertEqual(analytics.events, [.loaded(symbol: "AAPL")])`. It is a lock-guarded class, not an actor, because `track` is synchronous. `SpyCache` is the same idea for `store`.

## Mock: `MockQuoteAPI`

```swift
actor MockQuoteAPI: QuoteAPIClient {
  init(expectedSymbol: String, expectedCalls: Int = 1, result: ...)
  func verify(file: StaticString = #filePath, line: UInt = #line)
}
// test:
let api = MockQuoteAPI(expectedSymbol: "AAPL", expectedCalls: 1)
_ = await sut.find(for: "AAPL")
await api.verify()
```

**Why:** on a cache miss the repository must hit the API exactly once, for the requested symbol. The expectation is stated before the act step and the mock fails the test itself. `file:`/`line:` default arguments are evaluated at the call site, so the red marker lands on the test line. Checked by changing `expectedCalls` to 2 and watching it fail.

## Fake: `AcCache` + `FakeClock`

```swift
let cache = AcCache<Quote>(clock: FakeClock())
let sut = AcQuoteRepository(api: api, cache: cache)
_ = await sut.find(for: "AAPL")
let second = await sut.find(for: "AAPL")   // served from cache, API called once
```

**Why:** a real in-memory cache with a controllable clock. It proves store-then-find and TTL behaviour end to end, which `SpyCache` (canned `find`, records `store`) cannot. A separate `FakeQuoteCache` was deliberately not built: `AcCache` is already an in-memory implementation, so a second one would duplicate production logic and could drift from it.

## Choosing one

- Need a return value to drive the code? **Stub.**
- Need to check a side effect after the fact? **Spy.**
- Want the expectation written first and checked by the double? **Mock.** (Prefer a spy unless the call itself is the behaviour; mocks couple tests to implementation.)
- Need real behaviour without the real dependency (disk, network, time)? **Fake.**
- Parameter must be filled but is irrelevant? **Dummy.**

## "Mock vs Stub vs Spy?" (60 seconds)

> They are all test doubles that replace a real dependency, and they differ in what the test checks. A **stub** returns canned answers so I can drive the code into a state, then I assert on the result: state verification. A **spy** is a stub that also records how it was called, and I assert on those recordings afterwards: for example, that the analytics event was sent. A **mock** is pre-programmed with expectations, like "fetch AAPL exactly once", and it fails the test itself if reality differs: behaviour verification written up front. In practice I default to stubs and fakes, use a spy when the side effect has no return value, and reach for a mock only when the interaction itself is the requirement, because mocks tie tests to implementation details. In this repo: `StubQuoteRepository` drives view-model state, `SpyAnalyticsTracker` checks events, `MockQuoteAPI` checks the single API call on a cache miss, and `AcCache` with `FakeClock` is a fake.
