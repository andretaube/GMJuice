//
//  GMJuiceApp.swift
//  GMJuice
//
//  Created by Andre Taube on 10/6/25.
//

import SwiftUI
import SwiftData

@main
struct GMJuice: App {
    
    @StateObject private var bootstrap = AppInitializer()
    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject private var bleManager = BLEManager.shared
    @StateObject private var announcer = Announcer.shared
    
    @AppStorage("announcer_enabled") private var announcerEnabled = true
    init() {
        Announcer.shared.isEnabled = announcerEnabled
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ShooterProfile.self,
            DivisionProfile.self,
            StringRun.self,
            StringShot.self
        ])
                
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if bootstrap.isReady {
                    RootTabs()
                        .environmentObject(bleManager)
                        .onAppear {
                            bleManager.start()
                        }
                        .transition(.opacity.combined(with: .scale.combined(with: .move(edge: .bottom))))
                } else {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .task {
                bootstrap.start()
            }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                bleManager.start()
            }
        }
    }
}
