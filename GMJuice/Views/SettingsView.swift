import SwiftUI

struct SettingsView: View {
    @ObservedObject private var ble = SettingsViewModel.shared
    @ObservedObject private var announcer = Announcer.shared
    @EnvironmentObject private var notificationManager: NotificationManager
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"

    @State private var weeklyNotificationEnabled: Bool = true
    @State private var selectedDay: Int = 5  // Friday
    @State private var selectedHour: Int = 9  // 9 AM

    @State private var dailyNotificationEnabled: Bool = true
    @State private var dailyHour: Int = 8  // 8 AM
    @State private var dailyActiveDays: Set<Int> = [2, 3, 4, 5, 6]  // Mon-Fri
    
    var body: some View {
        NavigationStack {
            Form {

                Section("Connected Timer") {
                    HStack {
                        Text("Device")
                        Spacer()
                        Text(ble.savedName).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(ble.connectionStatus).foregroundColor(.secondary)
                    }
                }
                
                Section("Discovered Devices") {
                    ForEach(ble.devices) { dev in
                        Button {
                            BLEManager.shared.saveDevice(
                                id: dev.id,
                                name: dev.name.isEmpty ? "Unknown" : dev.name
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dev.name.isEmpty ? "Unknown" : dev.name)
                                    .font(.headline)
                                Text(dev.id.uuidString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Section("Appearance") {
                    Picker("Theme", selection: $appearanceMode) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Voice") {
                    Toggle("Announcements Enabled", isOn: $announcer.isEnabled)

                    Toggle("Speak on Silent", isOn: $announcer.speakOnSilent)

                    NavigationLink {
                        VoicePickerView()
                    } label: {
                        HStack {
                            Text("Voice")
                            Spacer()
                            if let voice = announcer.currentVoice() {
                                Text(voice.name)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Toggle("Weekly Summary", isOn: $weeklyNotificationEnabled)
                        .onChange(of: weeklyNotificationEnabled) { _, newValue in
                            notificationManager.weeklyNotificationEnabled = newValue
                        }

                    if weeklyNotificationEnabled {
                        Picker("Day", selection: $selectedDay) {
                            Text("Sunday").tag(0)
                            Text("Monday").tag(1)
                            Text("Tuesday").tag(2)
                            Text("Wednesday").tag(3)
                            Text("Thursday").tag(4)
                            Text("Friday").tag(5)
                            Text("Saturday").tag(6)
                        }
                        .onChange(of: selectedDay) { _, newValue in
                            notificationManager.weeklyNotificationDay = newValue
                        }

                        Picker("Time", selection: $selectedHour) {
                            ForEach(0..<24) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                        .onChange(of: selectedHour) { _, newValue in
                            notificationManager.weeklyNotificationHour = newValue
                        }

//                        Button("Test Notification") {
//                            Task {
//                                await notificationManager.sendWeeklySummaryNow(modelContext: modelContext)
//                            }
//                        }
                    }

                    if !notificationManager.isAuthorized {
                        Text("Notifications are disabled. Please enable them in Settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Weekly Summary")
                } footer: {
                    Text("Receive a weekly summary of your practice sessions including total shots and best times.")
                }

                Section {
                    Toggle("Daily Reminder", isOn: $dailyNotificationEnabled)
                        .onChange(of: dailyNotificationEnabled) { _, newValue in
                            notificationManager.dailyNotificationEnabled = newValue
                        }

                    if dailyNotificationEnabled {
                        Picker("Time", selection: $dailyHour) {
                            ForEach(0..<24) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                        .onChange(of: dailyHour) { _, newValue in
                            notificationManager.dailyNotificationHour = newValue
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Active Days")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                DayToggle(day: 2, label: "M", isSelected: dailyActiveDays.contains(2)) {
                                    toggleDay(2)
                                }
                                DayToggle(day: 3, label: "T", isSelected: dailyActiveDays.contains(3)) {
                                    toggleDay(3)
                                }
                                DayToggle(day: 4, label: "W", isSelected: dailyActiveDays.contains(4)) {
                                    toggleDay(4)
                                }
                                DayToggle(day: 5, label: "T", isSelected: dailyActiveDays.contains(5)) {
                                    toggleDay(5)
                                }
                                DayToggle(day: 6, label: "F", isSelected: dailyActiveDays.contains(6)) {
                                    toggleDay(6)
                                }
                                DayToggle(day: 7, label: "S", isSelected: dailyActiveDays.contains(7)) {
                                    toggleDay(7)
                                }
                                DayToggle(day: 1, label: "S", isSelected: dailyActiveDays.contains(1)) {
                                    toggleDay(1)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Daily Training Reminder")
                } footer: {
                    Text("Consistent training is key to improvement. Get daily suggestions for which stages to practice and what to focus on.")
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            BLEManager.shared.startScanning()

            // Load notification settings
            weeklyNotificationEnabled = notificationManager.weeklyNotificationEnabled
            selectedDay = notificationManager.weeklyNotificationDay
            selectedHour = notificationManager.weeklyNotificationHour

            // Load daily notification settings
            dailyNotificationEnabled = notificationManager.dailyNotificationEnabled
            dailyHour = notificationManager.dailyNotificationHour
            dailyActiveDays = Set(notificationManager.dailyNotificationDays)
        }
        .onDisappear {
            BLEManager.shared.stopScanning()
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:00 a"
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return formatter.string(from: date)
    }

    private func toggleDay(_ day: Int) {
        if dailyActiveDays.contains(day) {
            dailyActiveDays.remove(day)
        } else {
            dailyActiveDays.insert(day)
        }
        // Update notification manager
        notificationManager.dailyNotificationDays = Array(dailyActiveDays).sorted()
    }
}

// MARK: - Day Toggle Button

struct DayToggle: View {
    let day: Int
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundColor(isSelected ? .white : .secondary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
import SwiftData

#Preview {
    let schema = Schema(versionedSchema: Schema001.self)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])

    return TabView {
        NavigationStack {
            SettingsView()
        }
        .tabItem {
            Label("Settings", systemImage: "gearshape")
        }
    }
    .environmentObject(BLEManager.shared)
    .environmentObject(NotificationManager.shared)
    .modelContainer(container)
}
#endif
