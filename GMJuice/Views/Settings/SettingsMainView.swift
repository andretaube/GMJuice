import SwiftUI

struct SettingsMainView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    @State private var navigationPath = NavigationPath()

    var columns: [GridItem] {
        // Use 3 columns in landscape (compact vertical size class), 2 in portrait
        let columnCount = verticalSizeClass == .compact ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                LazyVGrid(columns: columns, spacing: 16) {
                    SettingsCard(
                        title: "Timer",
                        icon: "timer",
                        color: .blue,
                        destination: TimerSettingsView()
                    )

                    SettingsCard(
                        title: "Voice",
                        icon: "speaker.wave.3",
                        color: .purple,
                        destination: VoiceSettingsView()
                    )

                    SettingsCard(
                        title: "Notifications",
                        icon: "bell.badge",
                        color: .orange,
                        destination: NotificationSettingsView()
                    )

                    SettingsCard(
                        title: "Widgets",
                        icon: "square.grid.2x2",
                        color: .green,
                        destination: WidgetSettingsView()
                    )

                    SettingsCard(
                        title: "Appearance",
                        icon: "paintbrush",
                        color: .pink,
                        destination: AppearanceSettingsView()
                    )

                    SettingsCard(
                        title: "Export Data",
                        icon: "square.and.arrow.up",
                        color: .cyan,
                        destination: ExportDataView()
                    )
                }

                // Legal Links
                VStack(spacing: 12) {
                    Divider()
                        .padding(.vertical, 8)

                    HStack(spacing: 20) {
                        Button {
                            showingTerms = true
                        } label: {
                            Text("Terms of Use")
                                .font(.footnote)
                                .foregroundStyle(.blue)
                        }

                        Text("•")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button {
                            showingPrivacy = true
                        } label: {
                            Text("Privacy Policy")
                                .font(.footnote)
                                .foregroundStyle(.blue)
                        }
                    }

                    Text("Version 1.0")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom)
                }
                .padding()
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    UserProfileButton()
                }
            }
            .sheet(isPresented: $showingTerms) {
                LegalDocumentView(
                    title: "Terms of Use",
                    content: LegalDocuments.termsOfUse
                )
            }
            .sheet(isPresented: $showingPrivacy) {
                LegalDocumentView(
                    title: "Privacy Policy",
                    content: LegalDocuments.privacyPolicy
                )
            }
            .onOpenURL { url in
                // Handle deep link from widget
                if url.scheme == "gmjuice" && url.host == "settings" && url.path == "/widget" {
                    navigationPath.append("widget")
                }
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "widget" {
                    WidgetSettingsView()
                }
            }
        }
    }
}

// MARK: - Settings Card

struct SettingsCard<Destination: View>: View {
    let title: String
    let icon: String
    let color: Color
    let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsMainView()
        .environmentObject(NotificationManager.shared)
}
