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
                CreateNoteView()
            }
            .sheet(item: $selectedNote) { note in
                NoteDetailView(note: note)
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
                    print("   Note \(index + 1): \(note.sessionType ?? "unknown") - \(note.sessionDate ?? note.createdDate)")
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
                    .onTapGesture {
                        selectedNote = note
                    }
            }
            .onDelete(perform: deleteNotes)
        }
    }

    private func deleteNotes(at offsets: IndexSet) {
        // Show confirmation for the first note in the selection
        if let index = offsets.first {
            noteToDelete = notes[index]
            showingDeleteConfirmation = true
        }
    }

    private func confirmDeleteNote(_ note: SessionNote) {
        print("🗑️ Deleting note: \(note.sessionType ?? "unknown") - \(note.sessionDate ?? note.createdDate)")
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Type indicator
                if let sessionType = note.sessionType {
                    Label(sessionType.capitalized, systemImage: sessionType == "match" ? "trophy.fill" : "figure.run")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Date
                Text(note.sessionDate ?? note.createdDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Summary (high-level overview)
            let content = note.processedContent
            if let summary = content.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack {
                // Overall score from quality ratings
                if let scoreEmoji = content.overallScoreEmoji(),
                   let scoreDisplay = content.overallScoreDisplay() {
                    HStack(spacing: 4) {
                        Text(scoreEmoji)
                            .font(.title2)
                        Text(scoreDisplay)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Overall")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Completion indicator - encourage adding more
                let completion = content.completionPercentage()
                if completion < 0.8 {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        Text("Add more")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NotesListView()
        .modelContainer(for: SessionNote.self, inMemory: true)
}
