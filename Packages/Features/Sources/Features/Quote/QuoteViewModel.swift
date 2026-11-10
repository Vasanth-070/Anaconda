//
//  QuoteViewModel.swift
//  Features
//
//  Created by Vasanth Gentela on 10/25/26.
//

import Foundation
import Observation

@MainActor @Observable
final class QuoteViewModel {
  enum State {
    case idle
    case loading
    case loaded(Quote)
    case stale(Quote)   // UI shows the "refresh failed" snackbar
    case failed(QuoteError)
  }

  private(set) var state: State = .idle
  private let repository: QuoteRepository
  private let analytics: AnalyticsTracker

  init(repository: QuoteRepository, analytics: AnalyticsTracker) {
    self.repository = repository
    self.analytics = analytics
  }

  func load(symbol: String) async {
    state = .loading
    switch await repository.find(for: symbol) {
    case .success(let result):
      switch result.status {
      case .hit:
        state = .loaded(result.data)
        analytics.track(.loaded(symbol: symbol))
      case .stale:
        state = .stale(result.data)
        analytics.track(.stale(symbol: symbol))
      }
    case .failure(let error):
      state = .failed(error)
      analytics.track(.failed(symbol: symbol, error: error))
    }
  }
}
