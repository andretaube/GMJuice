//
//  GMJuiceApp.swift
//  GMJuice
//
//  Created by Andre Taube on 10/6/25.

import SwiftUI
import SwiftData
import TipKit
import FirebaseCore


@main
struct GMJuice: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var bootstrap = AppInitializer()
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var bleManager = BLEManager.shared
    @StateObject private var announcer = Announcer.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    private let analytics = AnalyticsService.shared
    @State private var sessionStartTime = Date()

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
        let schema = Schema(versionedSchema: Schema010.self)

        // Migrate data from old app group location to default location if needed
        let appGroupID = "group.com.andretaube.gmjuice"
        let defaultURL = URL.applicationSupportDirectory.appending(path: "default.store")

        if let oldGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let oldStoreURL = oldGroupURL.appendingPathComponent("default.store")

            // If old data exists and new location doesn't, migrate it
            if FileManager.default.fileExists(atPath: oldStoreURL.path) &&
               !FileManager.default.fileExists(atPath: defaultURL.path) {
                print("📦 Migrating data from app group to default location...")

                do {
                    // Create destination directory if needed
                    try FileManager.default.createDirectory(
                        at: defaultURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )

                    // Copy the store file and its supporting files
                    let fileManager = FileManager.default
                    let oldDir = oldStoreURL.deletingLastPathComponent()

                    // Copy all files that start with "default.store"
                    let files = try fileManager.contentsOfDirectory(at: oldDir, includingPropertiesForKeys: nil)
                    for file in files where file.lastPathComponent.hasPrefix("default.store") {
                        let destURL = defaultURL.deletingLastPathComponent().appendingPathComponent(file.lastPathComponent)
                        try fileManager.copyItem(at: file, to: destURL)
                        print("  ✅ Copied \(file.lastPathComponent)")
                    }

                    print("✅ Data migration complete")
                } catch {
                    print("⚠️ Failed to migrate data: \(error)")
                    print("   Old data remains at app group location")
                }
            }
        }

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
                            
                            // Track session start
                            sessionStartTime = Date()
                            analytics.trackSessionStart()
                            
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
                
                // Track session start if coming from background
                sessionStartTime = Date()
                analytics.trackSessionStart()
            } else if phase == .background {
                // Track session end
                let sessionDuration = Date().timeIntervalSince(sessionStartTime)
                 analytics.trackSessionEnd(duration: sessionDuration)
                
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
