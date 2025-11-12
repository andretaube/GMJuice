import SwiftUI
import SwiftData
import Speech

struct CreateNoteViewV2: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var rawInput: String = ""
    @State private var sessionDate: Date = Date()
    @State private var sessionType: String = "practice"
    @State private var accumulatedInput: String = "" // All input accumulated

    // Speech recognition
    @State private var isRecording = false
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()

    // Processing state
    @State private var isProcessing = false
    @State private var processedContent: NoteContentV2?
    @State private var currentNote: SessionNote? // Track saved note

    // Follow-up questions
    @State private var showingFollowUp = false
    @State private var currentQuestion: FollowUpQuestion?
    @State private var followUpResponse: String = ""

    // Alerts
    @State private var showingErrorAlert = false
    @State private var errorMessage: String = ""

    var body: some View {
        NavigationView {
            Form {
                // Session type selection
                sessionTypeSection

                // Guidelines
                if processedContent == nil {
                    guidelinesSection
                }

                // Input section or preview
                if processedContent == nil {
                    inputSection
                } else {
                    previewSection
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingFollowUp) {
                FollowUpQuestionSheet(
                    question: currentQuestion,
                    response: $followUpResponse,
                    onSubmit: handleFollowUpSubmit,
                    onSkip: handleFollowUpSkip
                )
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                requestSpeechAuthorization()
            }
            .onDisappear {
                if isRecording {
                    stopRecording()
                }
            }
        }
    }

    // MARK: - Session Type Section

    private var sessionTypeSection: some View {
        Section {
            HStack(spacing: 16) {
                // Practice button
                Button(action: { sessionType = "practice" }) {
                    VStack(spacing: 6) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 24))
                            .foregroundColor(sessionType == "practice" ? .white : .blue)

                        Text("Practice")
                            .font(.subheadline)
                            .foregroundColor(sessionType == "practice" ? .white : .blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(
                        sessionType == "practice"
                            ? LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [.blue.opacity(0.1), .blue.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(sessionType == "practice" ? Color.clear : Color.blue.opacity(0.3), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)

                // Match button
                Button(action: { sessionType = "match" }) {
                    VStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 24))
                            .foregroundColor(sessionType == "match" ? .white : .orange)

                        Text("Match")
                            .font(.subheadline)
                            .foregroundColor(sessionType == "match" ? .white : .orange)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(
                        sessionType == "match"
                            ? LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [.orange.opacity(0.1), .orange.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(sessionType == "match" ? Color.clear : Color.orange.opacity(0.3), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Guidelines Section

    private var guidelinesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Quick Tip")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                }

                if sessionType == "practice" {
                    Text("Tell me about your practice. Try to cover:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        GuidelineRow(icon: "moon.stars.fill", text: "Your physical condition (sleep, food, warmup)")
                        GuidelineRow(icon: "target", text: "How you performed (focus, speed, accuracy)")
                        GuidelineRow(icon: "cloud.sun.fill", text: "Conditions (weather, equipment, people)")
                        GuidelineRow(icon: "star.fill", text: "What went well or needs work")
                    }
                    .padding(.leading, 8)
                } else {
                    Text("How was the match? Try to cover:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        GuidelineRow(icon: "moon.stars.fill", text: "Your physical condition (sleep, food, warmup)")
                        GuidelineRow(icon: "target", text: "How you performed (focus, speed, accuracy)")
                        GuidelineRow(icon: "cloud.sun.fill", text: "Conditions (weather, equipment, people)")
                        GuidelineRow(icon: "star.fill", text: "What went well or needs work")
                    }
                    .padding(.leading, 8)
                }
            }
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        Section("Your Notes") {
            VStack(alignment: .leading, spacing: 16) {
                // Speak button
                if !isRecording {
                    Button(action: startRecording) {
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

                // Done button (when recording or has input)
                if isRecording || !rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack {
                        Spacer()
                        Button(action: {
                            if isRecording {
                                stopRecording()
                            }
                            Task {
                                await processInput()
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
                        Spacer()
                    }
                }

                // Text editor (when not recording)
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

                // Recording indicator
                if isRecording {
                    recordingIndicator
                }

                // Processing indicator
                if isProcessing {
                    processingIndicator
                }
            }
        }
    }

    private var recordingIndicator: some View {
        VStack(spacing: 12) {
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

    private var processingIndicator: some View {
        VStack(spacing: 12) {
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

    // MARK: - Preview Section

    private var previewSection: some View {
        Section {
            if let content = processedContent {
                PreviewContent(content: content, onAddMore: {
                    // Clear processed content to go back to input
                    processedContent = nil
                    rawInput = ""
                }, onSave: {
                    saveAndDismiss()
                })
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

    private func startRecording() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
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
                if let result = result, isRecording {
                    DispatchQueue.main.async {
                        rawInput = result.bestTranscription.formattedString
                    }
                }
            }

            isRecording = true
        } catch {
            print("Error starting recording: \(error)")
        }
    }

    private func stopRecording() {
        isRecording = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    // MARK: - Processing

    private func processInput() async {
        guard !rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isProcessing = true

        // Accumulate input
        if !accumulatedInput.isEmpty {
            accumulatedInput += "\n\n"
        }
        accumulatedInput += rawInput

        do {
            let service = ClaudeNoteServiceV2()

            guard service.isConfigured else {
                await MainActor.run {
                    errorMessage = "AI service is not configured. Please add your API key in Settings."
                    showingErrorAlert = true
                    isProcessing = false
                }
                return
            }

            let content = try await service.processNote(
                rawInput: accumulatedInput,
                sessionType: sessionType
            )

            await MainActor.run {
                processedContent = content
                rawInput = "" // Clear current input

                // Decide what to do based on save worthiness
                switch content.estimatedSaveWorthiness {
                case .autoSave:
                    // Auto-save and show success
                    autoSaveNote(content: content)
                case .review:
                    // Show preview for user review
                    break
                case .needsMore:
                    // Show follow-up question if available
                    if let firstQuestion = content.missingCriticalInfo.first {
                        currentQuestion = firstQuestion
                        showingFollowUp = true
                    }
                }

                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to process note. Please try again."
                showingErrorAlert = true
                isProcessing = false
            }
        }
    }

    private func handleFollowUpSubmit() {
        guard !followUpResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let content = processedContent else {
            return
        }

        Task {
            isProcessing = true

            do {
                let service = ClaudeNoteServiceV2()
                let updated = try await service.updateNote(
                    currentContent: content,
                    additionalInput: followUpResponse,
                    targetQuestion: currentQuestion
                )

                await MainActor.run {
                    processedContent = updated
                    followUpResponse = ""
                    currentQuestion = nil

                    // Check if more follow-ups needed
                    if updated.estimatedSaveWorthiness == .needsMore,
                       let nextQuestion = updated.missingCriticalInfo.first {
                        currentQuestion = nextQuestion
                        showingFollowUp = true
                    }

                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to update note. Please try again."
                    showingErrorAlert = true
                    isProcessing = false
                }
            }
        }
    }

    private func handleFollowUpSkip() {
        // Check if there are more questions
        if let content = processedContent,
           let remaining = content.missingCriticalInfo.dropFirst().first {
            currentQuestion = remaining
            showingFollowUp = true
        } else {
            currentQuestion = nil
        }
    }

    // MARK: - Saving

    private func autoSaveNote(content: NoteContentV2) {
        if let existing = currentNote {
            // Update existing
            existing.rawInput = accumulatedInput
            existing.processedContentV2 = content
            existing.lastModifiedDate = Date()
        } else {
            // Create new
            let note = SessionNote(
                rawInput: accumulatedInput,
                sessionDate: sessionDate,
                sessionType: sessionType
            )
            note.processedContentV2 = content
            modelContext.insert(note)
            currentNote = note
        }

        do {
            try modelContext.save()
            print("Note saved successfully")
        } catch {
            print("Error saving note: \(error)")
            errorMessage = "Failed to save note."
            showingErrorAlert = true
        }
    }

    private func saveAndDismiss() {
        if let content = processedContent {
            autoSaveNote(content: content)
        }
        dismiss()
    }
}

// MARK: - Supporting Views

struct GuidelineRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct PreviewContent: View {
    let content: NoteContentV2
    let onAddMore: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Preview header
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text("Preview Your Note")
                        .font(.title3)
                        .fontWeight(.bold)
                }

                if let summary = content.summary {
                    Text(summary)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Overall score
                if let scoreDisplay = content.overallScoreDisplay(),
                   let scoreEmoji = content.overallScoreEmoji() {
                    HStack(spacing: 10) {
                        Text(scoreEmoji)
                            .font(.system(size: 44))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scoreDisplay)
                                .font(.title)
                                .fontWeight(.bold)
                            Text("Overall Score")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color(.systemGray6), Color(.systemGray5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                }

                // Completeness indicator
                HStack {
                    Text("Completeness:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: content.completeness)
                        .tint(.blue)
                    Text("\(Int(content.completeness * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .background(Color.green.opacity(0.05))
            .cornerRadius(16)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onAddMore) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add More")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: onSave) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Save")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            // Missing info prompts
            if !content.missingCriticalInfo.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Consider adding:")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(content.missingCriticalInfo.prefix(3)) { question in
                        HStack {
                            Image(systemName: "arrow.right.circle")
                                .foregroundStyle(.blue)
                            Text(question.question)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
            }
        }
    }
}

struct FollowUpQuestionSheet: View {
    let question: FollowUpQuestion?
    @Binding var response: String
    let onSubmit: () -> Void
    let onSkip: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let question = question {
                    VStack(spacing: 12) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.blue)

                        Text(question.question)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top)

                    TextEditor(text: $response)
                        .frame(minHeight: 150)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        Button("Skip") {
                            onSkip()
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)

                        Button("Submit") {
                            onSubmit()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Quick Question")
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

#Preview {
    CreateNoteViewV2()
        .modelContainer(for: SessionNote.self, inMemory: true)
}
