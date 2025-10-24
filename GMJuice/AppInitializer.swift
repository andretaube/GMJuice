//
//  AppInitializer.swift
//  GMJuice
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
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            // Request notification permissions
            await NotificationManager.shared.requestPermission()
            await NotificationManager.shared.checkAuthorizationStatus()

            withAnimation(.easeInOut(duration: 0.35)) {
                self.isReady = true
            }
        }
    }
}
