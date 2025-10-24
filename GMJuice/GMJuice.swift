//
//  GMJuiceApp.swift
//  GMJuice
//
//  Created by Andre Taube on 10/6/25.

import SwiftUI
import SwiftData

@main
struct GMJuice: App {
    
    @StateObject private var bootstrap = AppInitializer()
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var bleManager = BLEManager.shared
    @StateObject private var announcer = Announcer.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    @State private var orientationManager = DeviceOrientationManager()
    
    @AppStorage("announcer_enabled") private var announcerEnabled = true
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    
    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    init() {
        Announcer.shared.isEnabled = announcerEnabled
    }
    
    var sharedModelContainer: ModelContainer = {
        // Use the latest versioned schema and provide the migration plan
        let schema = Schema(versionedSchema: Schema001.self)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
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
                        .environmentObject(notificationManager)
                        .onAppear {
                            bleManager.start()
                        }
                        .transition(.opacity.combined(with: .scale.combined(with: .move(edge: .bottom))))
                        .environment(orientationManager)
                } else {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .task {
                bootstrap.start()
            }
            .preferredColorScheme(colorScheme)

        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                bleManager.start()
            } else if phase == .background {
                // Update notifications with fresh data when app goes to background
                notificationManager.updateScheduledNotification(modelContext: sharedModelContainer.mainContext)
                notificationManager.updateDailyNotifications()
            }
        }
    }
}

#Preview {
    let schema = Schema(versionedSchema: Schema001.self)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    return RootTabs()
        .environmentObject(BLEManager.shared)
        .environmentObject(NotificationManager.shared)
        .modelContainer(container)
}
