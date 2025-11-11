import SwiftUI

struct NotesSettingsView: View {
    @AppStorage("claude_api_key") private var apiKey: String = ""
    @State private var showAPIKey: Bool = false
    @State private var tempAPIKey: String = ""
    @State private var isEditingKey: Bool = false

    var body: some View {
        Form {
            Section {
                Text("Notes use Claude AI to help you create structured summaries of your shooting sessions. Claude analyzes your input and extracts key information into organized sections.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } header: {
                Text("About Notes")
            }

            Section {
                if apiKey.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("API Key Required")
                                .fontWeight(.semibold)
                        }

                        Text("To use the Notes feature, you need to provide your own Anthropic API key. This ensures your data remains private and you have full control.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button("Add API Key") {
                            isEditingKey = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("API Key Configured")
                                .fontWeight(.semibold)
                        }

                        if showAPIKey {
                            Text(apiKey)
                                .font(.system(.footnote, design: .monospaced))
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                        } else {
                            Text(String(repeating: "•", count: 24))
                                .font(.system(.footnote, design: .monospaced))
                        }

                        HStack {
                            Button(showAPIKey ? "Hide Key" : "Show Key") {
                                showAPIKey.toggle()
                            }
                            .font(.footnote)

                            Spacer()

                            Button("Change Key") {
                                tempAPIKey = apiKey
                                isEditingKey = true
                            }
                            .font(.footnote)

                            Button("Remove") {
                                apiKey = ""
                            }
                            .font(.footnote)
                            .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("API Configuration")
            } footer: {
                if apiKey.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to get an API key:")
                        Text("1. Visit console.anthropic.com")
                        Text("2. Sign up or log in to your account")
                        Text("3. Navigate to API Keys section")
                        Text("4. Create a new API key")
                        Text("5. Copy and paste it here")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Note Sections")
                        .font(.headline)

                    ForEach(NoteSections.all) { section in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: section.required ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(section.required ? .blue : .secondary)
                                .font(.caption)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text(section.prompt)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Note Structure")
            } footer: {
                Text("Sections marked with • are required for a complete note (~80% target)")
                    .font(.caption)
            }

            Section {
                Link(destination: URL(string: "https://www.anthropic.com/api")!) {
                    HStack {
                        Text("Anthropic API Documentation")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                }

                Link(destination: URL(string: "https://console.anthropic.com")!) {
                    HStack {
                        Text("Anthropic Console")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                }
            } header: {
                Text("Resources")
            }
        }
        .navigationTitle("Notes & AI")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditingKey) {
            APIKeyInputView(apiKey: $apiKey, tempKey: $tempAPIKey)
        }
    }
}

// MARK: - API Key Input Sheet

struct APIKeyInputView: View {
    @Binding var apiKey: String
    @Binding var tempKey: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Enter your Anthropic API key. This key is stored securely on your device and is only used to process your notes.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Section("API Key") {
                    SecureField("sk-ant-...", text: $tempKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.system(.body, design: .monospaced))
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy & Security")
                            .font(.headline)

                        Text("• Your API key is stored locally on your device")
                        Text("• Notes are sent directly to Anthropic's servers")
                        Text("• GMJuice does not store or access your notes")
                        Text("• You maintain full control of your data")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Enter API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        tempKey = ""
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        apiKey = tempKey
                        tempKey = ""
                        dismiss()
                    }
                    .disabled(tempKey.isEmpty || !tempKey.hasPrefix("sk-ant-"))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotesSettingsView()
    }
}
