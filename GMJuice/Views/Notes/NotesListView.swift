import SwiftUI
import SwiftData

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SessionNote.createdDate, order: .reverse) private var notes: [SessionNote]

    @State private var showingCreateNote = false
    @State private var selectedNote: SessionNote?
    @State private var noteToDelete: SessionNote?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationView {
            Group {
                if notes.isEmpty {
                    emptyState
                } else {
                    notesList
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !notes.isEmpty {
                        EditButton()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingCreateNote = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateNote) {
                CreateNoteViewV2()
            }
            .sheet(item: $selectedNote) { note in
                NavigationStack {
                    NoteDetailViewV2(note: note)
                }
            }
            .alert("Delete Note?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    noteToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let note = noteToDelete {
                        confirmDeleteNote(note)
                    }
                    noteToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this note? This action cannot be undone.")
            }
            .onAppear {
                print("📝 Notes List loaded: \(notes.count) notes found")
                for (index, note) in notes.enumerated() {
                    print("   Note \(index + 1): \(note.sessionType) - \(note.sessionDate)")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Notes Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create notes after matches or practice sessions to track your progress and experiences")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { showingCreateNote = true }) {
                Label("Create Note", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
    }

    private var notesList: some View {
        List {
            ForEach(notes) { note in
                NoteRow(note: note)
                    .contentShape(Rectangle())
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .onTapGesture {
                        selectedNote = note
                    }
            }
            .onDelete(perform: deleteNotes)
        }
        .listStyle(.plain)
    }

    private func deleteNotes(at offsets: IndexSet) {
        // Show confirmation for the first note in the selection
        if let index = offsets.first {
            noteToDelete = notes[index]
            showingDeleteConfirmation = true
        }
    }

    private func confirmDeleteNote(_ note: SessionNote) {
        print("🗑️ Deleting note: \(note.sessionType) - \(note.sessionDate)")
        modelContext.delete(note)

        do {
            try modelContext.save()
            print("✅ Note deleted successfully")
        } catch {
            print("❌ Error deleting note: \(error)")
        }
    }
}

struct NoteRow: View {
    let note: SessionNote

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with type and date
            HStack(alignment: .top) {
                // Type indicator with icon
                HStack(spacing: 6) {
                    Image(systemName: note.sessionType == "match" ? "trophy.fill" : "figure.run")
                        .font(.title3)
                        .foregroundStyle(note.sessionType == "match" ? .orange : .blue)
                    Text(note.sessionType.capitalized)
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                Spacer()

                // Date
                Text(note.sessionDate, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Summary (high-level overview)
            let content = note.processedContentV2
            if let summary = content.summary {
                Text(summary)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }

            // Domain indicators
            HStack(spacing: 8) {
                // Preparation
                if content.preparation.averageScore() != nil {
                    DomainBadge(icon: "moon.stars.fill", color: .purple, score: content.preparation.averageScore())
                }
                // Performance
                if content.performance.averageScore() != nil {
                    DomainBadge(icon: "target", color: .blue, score: content.performance.averageScore())
                }
                // External
                if content.external.averageScore() != nil {
                    DomainBadge(icon: "cloud.sun.fill", color: .cyan, score: content.external.averageScore())
                }
                // Outcomes
                if content.outcomes.hasContent() {
                    DomainBadge(icon: "star.fill", color: .yellow, score: nil)
                }

                // Linked indicator
                if !note.linkedStringRunIds.isEmpty || note.linkedMatchName != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            // Footer with overall score and completion
            HStack {
                // Overall score
                if let scoreEmoji = content.overallScoreEmoji(),
                   let scoreDisplay = content.overallScoreDisplay() {
                    HStack(spacing: 6) {
                        Text(scoreEmoji)
                            .font(.title3)
                        Text(scoreDisplay)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                Spacer()

                // Completion indicator
                if note.completeness < 0.8 {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("\(Int(note.completeness * 100))%")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Complete")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct DomainBadge: View {
    let icon: String
    let color: Color
    let score: Double?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)

            if let score = score {
                Text(String(format: "%.1f", score))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    NotesListView()
        .modelContainer(for: SessionNote.self, inMemory: true)
}
