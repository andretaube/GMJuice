//
//  SplashView.swift
//  GMJuice
//
//  Created by Andre Taube on 10/8/25.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 64, weight: .bold))
                Text("Steel Challenge").font(.title.bold())
                Text("Training Log").font(.title.bold())
                ProgressView().padding(.top, 8)
            }
        }
        // Accessibility: announce loading state
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading")
    }
}
