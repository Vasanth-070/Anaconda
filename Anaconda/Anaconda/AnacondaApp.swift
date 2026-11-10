//
//  AnacondaApp.swift
//  Anaconda
//
//  Created by Vasanth Gentela on 10/18/26.
//

import SwiftUI
import Features
@main
struct AnacondaApp: App {
    // Composition root: the only place that picks which dependencies the app runs on.
    // `.dev` = faked HTTP (offline). Switch to `.live` once a quote provider exists.
    private let dependencies = AppDependencies.dev

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: dependencies.makeQuoteViewModel())
        }
    }
}
