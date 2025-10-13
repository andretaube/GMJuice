//
//  AppInitializer.swift
//  TrainingApp
//
//  Created by Andre Taube on 10/8/25.
//


import SwiftUI

@MainActor
final class AppInitializer: ObservableObject {
    @Published var isReady = false

    func start() {
        // Kick off your startup work
        Task {
            // Simulate work: config, auth, DB migrations, warm caches, etc.
            try? await Task.sleep(nanoseconds: 1_200_000_000)

            // Do real tasks here:
            // await AuthManager.shared.restoreSession()
            // try await DataBootstrapper.shared.preload()

            withAnimation(.easeInOut(duration: 0.35)) {
                self.isReady = true
            }
        }
    }
}
