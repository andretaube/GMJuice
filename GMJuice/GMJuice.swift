//
//  GMJuiceApp.swift
//  GMJuice
//
//  Created by Andre Taube on 10/6/25.

import SwiftUI
import SwiftData
import TipKit

@main
struct GMJuice: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var bootstrap = AppInitializer()
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var bleManager = BLEManager.shared
    @StateObject private var announcer = Announcer.shared
    @StateObject private var notificationManager = NotificationManager.shared

    @AppStorage("announcer_enabled") private var announcerEnabled = true
    @AppStorage("appearanceMode") private var appearanceMode: String = "dark"
    @AppStorage("hasAcceptedTerms") private var hasAcceptedTerms = false

    @State private var showingTermsAcceptance = false

    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return .dark  // Default to dark if unrecognized
        }
    }

    init() {
        Announcer.shared.isEnabled = announcerEnabled

        // Configure TipKit
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: Schema007.self)

        // Use App Group for data sharing with widget
        let appGroupID = "group.com.andretaube.gmjuice"
        let modelURL: URL

        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            modelURL = groupURL.appendingPathComponent("default.store")
        } else {
            // Fallback to default location if App Group not configured
            modelURL = URL.applicationSupportDirectory.appending(path: "default.store")
        }

        let modelConfiguration = ModelConfiguration(url: modelURL)

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
                            // Check if user needs to accept terms
                            if !hasAcceptedTerms {
                                showingTermsAcceptance = true
                            }
                        }
                        .transition(.opacity.combined(with: .scale.combined(with: .move(edge: .bottom))))
                        .fullScreenCover(isPresented: $showingTermsAcceptance) {
                            TermsAcceptanceView(isPresented: $showingTermsAcceptance)
                        }
                        .onChange(of: hasAcceptedTerms) { _, newValue in
                            if newValue {
                                showingTermsAcceptance = false
                            }
                        }
                } else {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .task {
                bootstrap.start(modelContext: sharedModelContainer.mainContext)
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
    let schema = Schema(versionedSchema: Schema004.self)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])

    return RootTabs()
        .environmentObject(BLEManager.shared)
        .environmentObject(NotificationManager.shared)
        .modelContainer(container)
}
