import Features

/// Placeholder production tracker: prints events. Swap for a real backend later.
struct ConsoleAnalyticsTracker: AnalyticsTracker {
  func track(_ event: QuoteAnalyticsEvent) {
    print("[analytics] \(event)")
  }
}
