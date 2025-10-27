import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $appearanceMode) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Appearance")
            } footer: {
                Text("Choose how the app should look. System mode will match your device settings.")
            }
        }
        .navigationTitle("Appearance")
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
