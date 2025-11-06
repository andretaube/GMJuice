//
//  GMJuiceApp.swift
//  GMJuice
//
//  Created by Andre Taube on 10/6/25.

import SwiftUI
import SwiftData

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
    @AppStorage("hasSeenSCSAOnboarding") private var hasSeenSCSAOnboarding = false

    @State private var showingTermsAcceptance = false
    @State private var showingSCSAOnboarding = false

    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return .dark  // Default to dark if unrecognized
        }
    }

    init() {
        Announcer.shared.isEnabled = announcerEnabled
    }

    private func checkSCSAOnboarding() {
        // Only show if haven't seen it before
        guard !hasSeenSCSAOnboarding else { return }

        // Check if user has a profile with SCSA number
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<ShooterProfile>()

        guard let profile = try? context.fetch(descriptor).first else {
            // No profile yet - show onboarding
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingSCSAOnboarding = true
                hasSeenSCSAOnboarding = true
            }
            return
        }

        // Has profile but no SCSA number - show onboarding
        if profile.uspsaNumber.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingSCSAOnboarding = true
                hasSeenSCSAOnboarding = true
            }
        } else {
            // Has SCSA number - mark as seen
            hasSeenSCSAOnboarding = true
        }
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: Schema004.self)
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
                            // Check if user needs to accept terms
                            if !hasAcceptedTerms {
                                showingTermsAcceptance = true
                            } else {
                                // Terms already accepted - check SCSA onboarding
                                checkSCSAOnboarding()
                            }
                        }
                        .transition(.opacity.combined(with: .scale.combined(with: .move(edge: .bottom))))
                        .fullScreenCover(isPresented: $showingTermsAcceptance) {
                            TermsAcceptanceView(isPresented: $showingTermsAcceptance)
                        }
                        .sheet(isPresented: $showingSCSAOnboarding) {
                            SCSAOnboardingView(isPresented: $showingSCSAOnboarding)
                                .interactiveDismissDisabled(false)
                        }
                        .onChange(of: hasAcceptedTerms) { _, newValue in
                            if newValue {
                                showingTermsAcceptance = false
                                // After accepting terms, check if they need SCSA onboarding
                                checkSCSAOnboarding()
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
