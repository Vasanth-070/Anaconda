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

  init(repository: QuoteRepository) {
    self.repository = repository
  }

  func load(symbol: String) async {
    state = .loading
    switch await repository.find(for: symbol) {
    case .success(let result):
      switch result.status {
      case .hit: state = .loaded(result.data)
      case .stale: state = .stale(result.data)
      }
    case .failure(let error):
      state = .failed(error)
    }
  }
}
