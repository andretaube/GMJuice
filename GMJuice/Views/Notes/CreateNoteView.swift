import SwiftUI
import SwiftData
import Speech

struct CreateNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var allNotes: [SessionNote]

    @State private var rawInput: String = ""
    @State private var sessionDate: Date = Date()
    @State private var sessionType: String = "practice"
    @State private var accumulatedInput: String = "" // All input accumulated so far

    // Speech recognition
    @State private var isRecording = false
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var shouldAutoProcess = false

    // Processing state
    @State private var isProcessing = false
    @State private var processedContent: NoteContent?
    @State private var showingPrompt = false
    @State private var currentPromptSection: NoteSection?
    @State private var promptResponse: String = ""
    @State private var showingErrorAlert = false
    @State private var errorAlertMessage: String = ""

    // Note management
    @State private var currentNote: SessionNote? // The note being edited/created
    @State private var showingDuplicateAlert = false
    @State private var navigateToDetail = false // Navigate to detail after save

    var body: some View {
        NavigationView {
            Form {
                // Prominent session type toggle buttons
                Section {
                    HStack(spacing: 16) {
                        // Practice button
                        Button(action: {
                            sessionType = "practice"
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 36))
                                    .foregroundColor(sessionType == "practice" ? .white : .blue)

                                Text("Practice")
                                    .font(.headline)
                                    .foregroundColor(sessionType == "practice" ? .white : .blue)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                sessionType == "practice"
                                    ? LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [.blue.opacity(0.1), .blue.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                            )
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(sessionType == "practice" ? Color.clear : Color.blue.opacity(0.3), lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)

                        // Match button
                        Button(action: {
                            sessionType = "match"
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(sessionType == "match" ? .white : .orange)

                                Text("Match")
                                    .font(.headline)
                                    .foregroundColor(sessionType == "match" ? .white : .orange)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                sessionType == "match"
                                    ? LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [.orange.opacity(0.1), .orange.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                            )
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(sessionType == "match" ? Color.clear : Color.orange.opacity(0.3), lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)
                }

                // Categories to cover
                if processedContent == nil {
                    Section {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "list.bullet.clipboard.fill")
                                    .foregroundColor(.blue)
                                Text("Cover these categories:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                            }

                            // Categories grid
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                CategoryLegendItem(icon: "sparkles", title: "Performance", color: .purple)
                                CategoryLegendItem(icon: "wrench.and.screwdriver", title: "Equipment", color: .orange)
                                CategoryLegendItem(icon: "cloud.sun", title: "Conditions", color: .cyan)
                                CategoryLegendItem(icon: "brain.head.profile", title: "Mental", color: .pink)
                                CategoryLegendItem(icon: "figure.walk", title: "Physical", color: .green)
                                CategoryLegendItem(icon: "person.2", title: "Squad", color: .indigo)
                                CategoryLegendItem(icon: "target", title: "To Work On", color: .red)
                                CategoryLegendItem(icon: "note.text", title: "Other", color: .gray)
                            }
                        }
                    }
                }

                Section("Your Notes") {
                    if processedContent == nil {
                        // Initial input
                        VStack(alignment: .leading, spacing: 16) {
                            // Prominent speak button at the top
                            if !isRecording {
                                Button(action: {
                                    print("🔵 Speak button tapped")
                                    startRecording()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 18))
                                        Text("Tap to Speak")
                                            .font(.callout)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        LinearGradient(
                                            colors: [.blue, .blue.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                    .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                                }
                                .disabled(speechRecognizer == nil || isProcessing)
                            }

                            HStack(spacing: 12) {
                                Spacer()

                                if !isRecording {

                                    let hasInput = !rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                                    if hasInput {
                                        Button(action: {
                                            print("🟢 Green Done button tapped!")
                                            Task {
                                                await addAndProcess()
                                            }
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title2)
                                                Text("Done")
                                                    .fontWeight(.semibold)
                                            }
                                            .foregroundColor(.green)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 16)
                                        }
                                        .disabled(isProcessing)
                                    }
                                } else {
                                    Button(action: {
                                        print("🔴 Red Done button tapped (stop recording and save)")
                                        stopRecording()
                                        // Auto-process after stopping recording
                                        Task {
                                            await addAndProcess()
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title2)
                                            Text("Done")
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(.green)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                    }
                                }

                                Spacer()
                            }

                            // Text editor for typing
                            if !isRecording {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Or type your notes:")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    TextEditor(text: $rawInput)
                                        .frame(minHeight: 150)
                                        .scrollContentBackground(.hidden)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                            }

                            if isRecording {
                                VStack(spacing: 12) {
                                    // Animated microphone icon
                                    ZStack {
                                        Circle()
                                            .fill(Color.red.opacity(0.1))
                                            .frame(width: 80, height: 80)
                                            .scaleEffect(isRecording ? 1.2 : 1.0)
                                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isRecording)

                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(.red)
                                            .symbolEffect(.pulse, options: .repeating)
                                    }

                                    HStack(spacing: 6) {
                                        Image(systemName: "waveform")
                                            .foregroundColor(.red)
                                            .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                                        Text("I'm listening...")
                                            .font(.headline)
                                            .foregroundColor(.red)
                                    }

                                    Text("Speak naturally, I'll organize it for you")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.red.opacity(0.05))
                                .cornerRadius(12)
                            }

                            if isProcessing {
                                VStack(spacing: 12) {
                                    // Animated processing indicator
                                    ZStack {
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.blue, .purple],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 3
                                            )
                                            .frame(width: 60, height: 60)
                                            .rotationEffect(.degrees(isProcessing ? 360 : 0))
                                            .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isProcessing)

                                        Image(systemName: "sparkles")
                                            .font(.system(size: 24))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.blue, .purple],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .symbolEffect(.pulse, options: .repeating)
                                    }

                                    VStack(spacing: 4) {
                                        Text("Processing your notes...")
                                            .font(.headline)
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.blue, .purple],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                        Text("Organizing into categories")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            }
                        }
                    } else if let content = processedContent {
                        // Show overall score
                        if let scoreEmoji = content.overallScoreEmoji(),
                           let scoreDisplay = content.overallScoreDisplay() {
                            HStack(spacing: 8) {
                                Text(scoreEmoji)
                                    .font(.system(size: 40))
                                Text(scoreDisplay)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Text("Overall")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }

                        // Show processed content
                        ForEach(NoteSections.all) { section in
                            if let sectionContent = content.content(for: section.id),
                               !sectionContent.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(section.title)
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
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.vertical, 4)
                            }
                        }

                        // Show helpful suggestions for adding more info
                        if !content.hasMinimalDetail || !content.missingInfoPrompts.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                // Header
                                HStack(spacing: 10) {
                                    Image(systemName: "hand.point.up.left.fill")
                                        .foregroundColor(.blue)
                                        .font(.title2)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Add more details to improve your note")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        if !content.hasMinimalDetail {
                                            Text("Your note is a bit brief. Adding more specifics will make it more useful later.")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                }

                                // Specific suggestions
                                if !content.missingInfoPrompts.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Try adding:")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)

                                        ForEach(content.missingInfoPrompts, id: \.self) { prompt in
                                            HStack(alignment: .top, spacing: 10) {
                                                Image(systemName: "arrow.right.circle.fill")
                                                    .foregroundColor(.blue)
                                                    .font(.caption)
                                                Text(prompt)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                    .padding(.top, 8)
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.08))
                            .cornerRadius(12)
                        }

                        Divider()
                            .padding(.vertical, 8)

                        // Add More button - clear to allow new input
                        Button(action: {
                            // Clear to go back to input mode
                            // Keep accumulatedInput so AI can reprocess everything together
                            rawInput = ""
                            processedContent = nil // Clear to show input UI again
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add More")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isProcessing)

                        Text("Tap 'Add More' to speak or type additional details, then tap the green Done button again to update.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        // If there's processed content and a saved note, navigate to detail
                        if processedContent != nil && currentNote != nil {
                            navigateToDetail = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $navigateToDetail, onDismiss: {
                dismiss() // Dismiss create view after detail view is dismissed
            }) {
                if let note = currentNote {
                    NoteDetailView(note: note)
                }
            }
            .sheet(isPresented: $showingPrompt) {
                PromptSheetView(
                    section: currentPromptSection,
                    response: $promptResponse,
                    onSubmit: { response in
                        Task {
                            await addMoreInformation(response)
                        }
                    }
                )
            }
            .onAppear {
                requestSpeechAuthorization()
            }
            .onDisappear {
                if isRecording {
                    stopRecording()
                }
            }
            .onChange(of: rawInput) { oldValue, newValue in
                let hasInput = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if hasInput != !oldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if hasInput {
                        print("✅ Input available → Green 'Done' button now visible (length: \(newValue.count))")
                    } else {
                        print("❌ Input cleared → Green 'Done' button now hidden")
                    }
                }
            }
            .alert("Note Already Exists", isPresented: $showingDuplicateAlert) {
                Button("Update Existing", role: .none) {
                    if let content = processedContent, let existing = currentNote {
                        // Merge with existing
                        let inputToSave = accumulatedInput.isEmpty ? rawInput : accumulatedInput
                        existing.rawInput = existing.rawInput + "\n\n--- Additional Notes ---\n" + inputToSave
                        existing.processedContent = content

                        do {
                            try modelContext.save()
                            print("✅ Merged with existing note")
                        } catch {
                            print("❌ Error merging: \(error)")
                        }
                    }
                }
                Button("Create New", role: .none) {
                    if let content = processedContent {
                        currentNote = nil // Clear so it creates new
                        autoSaveNote(content: content)
                    }
                }
                Button("Cancel", role: .cancel) {
                    currentNote = nil
                }
            } message: {
                Text("You already have a note for \(sessionDate.formatted(date: .abbreviated, time: .omitted)). Would you like to update the existing note or create a new one?")
            }
            .alert("Error Processing Note", isPresented: $showingErrorAlert) {
                Button("Try Again", role: .none) {
                    Task {
                        await processNote()
                    }
                }
                Button("Later", role: .cancel) {
                    // Do nothing
                }
            } message: {
                Text(errorAlertMessage)
            }
        }
    }

    // MARK: - Speech Recognition

    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                if status != .authorized {
                    speechRecognizer = nil
                }
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        print("🎤 Starting speech recognition...")
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ Speech recognizer not available")
            return
        }

        do {
            let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest = recognitionRequest
            recognitionRequest.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                // Only update if we're still recording
                if let result = result, isRecording {
                    DispatchQueue.main.async {
                        rawInput = result.bestTranscription.formattedString
                        print("📝 Transcribed: \(rawInput.prefix(50))...")
                    }
                }

                if let error = error {
                    print("❌ Speech recognition error: \(error)")
                }

                // Don't auto-stop - let user control with Done button
            }

            isRecording = true
            print("✅ Recording started successfully")
        } catch {
            print("❌ Error starting recording: \(error)")
        }
    }

    private func stopRecording() {
        guard isRecording else {
            print("⚠️ stopRecording called but already stopped")
            return
        }

        print("🛑 Stopping recording...")
        print("   Final raw input length: \(rawInput.count)")
        print("   Final raw input: \(rawInput)")

        isRecording = false // Set this FIRST to prevent further updates

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        print("✅ Recording stopped successfully")
        print("   Preserved input length: \(rawInput.count)")
    }

    // MARK: - Note Processing

    private func addAndProcess() async {
        print("➕ addAndProcess called")
        print("   Current rawInput: \(rawInput.prefix(100))")
        print("   Current accumulated: \(accumulatedInput.prefix(100))")

        // Accumulate the input
        if !accumulatedInput.isEmpty {
            accumulatedInput += "\n\n"
        }
        accumulatedInput += rawInput

        print("   New accumulated: \(accumulatedInput.prefix(100))")

        // Process the accumulated input
        await processNote()
    }

    private func processNote() async {
        print("🤖 Processing note...")
        isProcessing = true

        do {
            let service = ClaudeNoteService()

            guard service.isConfigured else {
                print("❌ Claude API not configured")
                errorAlertMessage = "AI service is not configured. Please contact support."
                showingErrorAlert = true
                isProcessing = false
                return
            }

            // Use accumulated input if available, otherwise use current input
            let inputToProcess = accumulatedInput.isEmpty ? rawInput : accumulatedInput
            print("📝 Input to process: \(inputToProcess.prefix(100))...")

            let content = try await service.processNote(rawInput: inputToProcess)
            print("✅ Note processed successfully")
            print("   Sections filled: \(content.sections.count)")
            print("   Completion: \(Int(content.completionPercentage() * 100))%")

            // Update the processed content on main thread
            await MainActor.run {
                processedContent = content
                // Clear current input after processing
                rawInput = ""

                // Auto-save the note
                autoSaveNote(content: content)
            }

        } catch {
            print("❌ Error processing note: \(error)")
            await MainActor.run {
                errorAlertMessage = "Failed to process note. Please try again."
                showingErrorAlert = true
            }
        }

        await MainActor.run {
            isProcessing = false
        }
    }

    private func autoSaveNote(content: NoteContent) {
        let inputToSave = accumulatedInput.isEmpty ? rawInput : accumulatedInput

        if let existing = currentNote {
            // Update existing note
            print("💾 Updating existing note...")
            existing.rawInput = inputToSave
            existing.processedContent = content

            do {
                try modelContext.save()
                print("✅ Note updated successfully")
            } catch {
                print("❌ Error updating note: \(error)")
                errorAlertMessage = "Failed to save note. Please try again."
                showingErrorAlert = true
            }
        } else {
            // Check for duplicate before creating
            if let existing = findExistingNoteForDate(sessionDate) {
                currentNote = existing
                showingDuplicateAlert = true
                return
            }

            // Create new note
            print("💾 Creating new note...")
            let note = SessionNote(
                rawInput: inputToSave,
                sessionDate: sessionDate,
                sessionType: sessionType
            )
            note.processedContent = content

            modelContext.insert(note)

            do {
                try modelContext.save()
                currentNote = note // Track this note for future updates
                print("✅ Note saved successfully")
            } catch {
                print("❌ Error saving note: \(error)")
                errorAlertMessage = "Failed to save note. Please try again."
                showingErrorAlert = true
            }
        }
    }

    private func promptForMissingInfo() {
        guard let content = processedContent else { return }
        let missing = content.missingSections()

        if let first = missing.first {
            currentPromptSection = first
            showingPrompt = true
        }
    }

    private func addMoreInformation(_ response: String) async {
        guard let content = processedContent else { return }

        isProcessing = true

        do {
            let service = ClaudeNoteService()
            let updated = try await service.updateNote(content: content, withAdditionalInput: response)
            processedContent = updated
            promptResponse = ""

            // Check if there are more missing sections
            if updated.completionPercentage() < 0.8 {
                promptForMissingInfo()
            }
        } catch {
            print("❌ Error adding more information: \(error)")
            errorAlertMessage = "Failed to update note. Please try again."
            showingErrorAlert = true
        }

        isProcessing = false
    }

    private func findExistingNoteForDate(_ date: Date) -> SessionNote? {
        let calendar = Calendar.current
        return allNotes.first { note in
            guard let noteDate = note.sessionDate ?? note.createdDate as Date? else { return false }
            return calendar.isDate(noteDate, inSameDayAs: date)
        }
    }
}

// MARK: - Prompt Sheet

struct PromptSheetView: View {
    let section: NoteSection?
    @Binding var response: String
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let section = section {
                    Text(section.prompt)
                        .font(.headline)
                        .padding()

                    TextEditor(text: $response)
                        .frame(minHeight: 150)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)

                    Button("Submit") {
                        if !response.isEmpty {
                            onSubmit(response)
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)

                    Spacer()
                }
            }
            .navigationTitle("Additional Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Reminder Item

struct ReminderItem: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Category Legend Item

struct CategoryLegendItem: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 11))
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

#Preview {
    CreateNoteView()
        .modelContainer(for: SessionNote.self, inMemory: true)
}
