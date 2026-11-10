//
//  ContentView.swift
//  Anaconda
//
//  Created by Vasanth Gentela on 10/18/26.
//

import SwiftUI
import Features

struct ContentView: View {
    let viewModel: QuoteViewModel

    var body: some View {
        VStack {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
            case .loaded(let quote):
                Text("\(quote.symbol): \(quote.price, specifier: "%.2f")")
            case .stale(let quote):
                Text("\(quote.symbol): \(quote.price, specifier: "%.2f") (stale)")
            case .failed(let error):
                Text("Failed: \(String(describing: error))")
            }
        }
        .padding()
        .task { await viewModel.load(symbol: "AAPL") }
    }
}

#Preview {
    ContentView(viewModel: AppDependencies.live.makeQuoteViewModel())
}
