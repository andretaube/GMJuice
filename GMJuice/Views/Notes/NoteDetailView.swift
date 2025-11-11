import SwiftUI
import SwiftData

struct NoteDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var note: SessionNote

    @State private var isEditing = false
    @State private var additionalInput: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var targetCategory: String? = nil // Category to target for updates
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Session Info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if let sessionType = note.sessionType {
                                Label(sessionType.capitalized, systemImage: sessionType == "match" ? "trophy.fill" : "figure.run")
                                    .font(.headline)
                            }

                            Spacer()

                            Text(note.sessionDate ?? note.createdDate, style: .date)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let matchName = note.linkedMatchName {
                            Text("Match: \(matchName)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Summary - Prominent at the top
                    let content = note.processedContent
                    if let summary = content.summary {
                        Text(summary)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }

                    // Note Sections - Tappable to edit
                    ForEach(NoteSections.all) { section in
                        if let sectionContent = content.content(for: section.id),
                           !sectionContent.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    // Dynamic title for match_performance section
                                    Text(sectionTitle(for: section))
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    // Quality rating indicator
                                    if let rating = content.qualityRating(for: section.id) {
                                        HStack(spacing: 4) {
                                            Text(rating.emoji)
                                                .font(.title3)
                                            Text("\(rating.rawValue)/5")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }

                                Text(sectionContent)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }

                    // Interactive completion suggestions
                    let completion = content.completionPercentage()
                    if completion < 0.8 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "hand.point.up.left.fill")
                                    .foregroundColor(.blue)
                                Text(interactivePrompt(for: content))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                            }

                            // Show specific missing sections if available
                            if !content.missingInfoPrompts.isEmpty {
                                ForEach(content.missingInfoPrompts.prefix(3), id: \.self) { prompt in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .foregroundColor(.blue)
                                            .fontWeight(.bold)
                                        Text(prompt)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }

                    // Add More or Change Button - Prominent at bottom
                    Button(action: {
                        targetCategory = nil // General update
                        additionalInput = ""
                        isEditing = true
                    }) {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                            Text("Add More or Change")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.top, 8)

                    // What you told me (collapsible)
                    DisclosureGroup("What You Told Me") {
                        VStack(alignment: .leading, spacing: 16) {
                            // Original input
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(note.createdDate.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .fontWeight(.semibold)
                                    Text("(Original)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text(note.rawInput)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }

                            // Addition history
                            if !note.additionHistory.isEmpty {
                                ForEach(Array(note.additionHistory.enumerated()), id: \.offset) { index, addition in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(addition.date.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption)
                                                .foregroundColor(.green)
                                                .fontWeight(.semibold)
                                            Text("(Addition \(index + 1))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(addition.input)
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.top, 8)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                    }

                    // Delete button at the bottom
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete Note")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                    }
                    .padding(.top, 24)
                }
                .padding()
            }
            .navigationTitle("Note Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isEditing) {
                NavigationView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Show which category is being updated
                        if let categoryId = targetCategory,
                           let section = NoteSections.section(withId: categoryId) {
                            HStack {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Updating: \(section.title)")
                                    .font(.headline)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        } else {
                            HStack {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Add More or Change")
                                    .font(.headline)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }

                        Text("Speak or type your update. You can target specific sections by saying \"for my equipment, also...\" or AI will place it automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        // Text editor for manual input
                        TextEditor(text: $additionalInput)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                Group {
                                    if additionalInput.isEmpty {
                                        Text("Type or use the microphone button to speak...")
                                            .foregroundColor(.gray)
                                            .padding(12)
                                            .allowsHitTesting(false)
                                    }
                                }
                                , alignment: .topLeading
                            )

                        // TODO: Add speech input button here if needed

                        if isProcessing {
                            HStack {
                                ProgressView()
                                Text("Processing update...")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }

                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Update Note")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isEditing = false
                                additionalInput = ""
                                targetCategory = nil
                                errorMessage = nil
                            }
                        }

                        ToolbarItem(placement: .primaryAction) {
                            Button("Update") {
                                Task {
                                    await updateNote()
                                }
                            }
                            .disabled(additionalInput.isEmpty || isProcessing)
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
            .alert("Delete Note?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteNote()
                }
            } message: {
                Text("Are you sure you want to delete this note? This action cannot be undone.")
            }
        }
    }

    private func updateNote() async {
        isProcessing = true
        errorMessage = nil

        do {
            let service = ClaudeNoteService()

            guard service.isConfigured else {
                errorMessage = "AI service is not configured. Please contact support."
                isProcessing = false
                return
            }

            let updated = try await service.updateNote(
                content: note.processedContent,
                withAdditionalInput: additionalInput,
                targetCategory: targetCategory
            )

            note.processedContent = updated

            // Track this addition with timestamp
            var history = note.additionHistory
            history.append(NoteAddition(date: Date(), input: additionalInput))
            note.additionHistory = history

            try modelContext.save()

            // Success - close the editing sheet
            await MainActor.run {
                additionalInput = ""
                targetCategory = nil
                isEditing = false
                errorMessage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    private func deleteNote() {
        modelContext.delete(note)
        try? modelContext.save()
        dismiss()
    }

    private func sectionTitle(for section: NoteSection) -> String {
        // Make "Overall Performance" title dynamic based on session type
        if section.id == "match_performance" {
            if let sessionType = note.sessionType {
                return sessionType == "match" ? "How was the overall match" : "How was the overall practice"
            }
            return "How was the overall session"
        }
        return section.title
    }

    private func interactivePrompt(for content: NoteContent) -> String {
        let missingSections = content.missingSections()

        if missingSections.isEmpty {
            return "Add more details to make your note complete"
        }

        // Generate interactive prompts based on what's missing
        let prompts = [
            "Tell me more about \(formatMissingSections(missingSections))",
            "Add more info about \(formatMissingSections(missingSections))",
            "Help me understand \(formatMissingSections(missingSections))",
            "Share more details about \(formatMissingSections(missingSections))"
        ]

        // Pick a random prompt for variety
        return prompts.randomElement() ?? prompts[0]
    }

    private func formatMissingSections(_ sections: [NoteSection]) -> String {
        let titles = sections.prefix(3).map { $0.title.lowercased() }

        if titles.count == 1 {
            return titles[0]
        } else if titles.count == 2 {
            return titles.joined(separator: " and ")
        } else {
            let allButLast = titles.dropLast().joined(separator: ", ")
            return "\(allButLast), and \(titles.last!)"
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: SessionNote.self, configurations: config)

    let note = SessionNote(rawInput: "Great match, no equipment issues, I was a little tired")
    container.mainContext.insert(note)

    return NoteDetailView(note: note)
        .modelContainer(container)
}
