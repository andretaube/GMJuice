#if DEBUG
import SwiftUI
import SwiftData

struct GenerateTestDataView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var numberOfRuns = 100
    @State private var daysBack = 30
    @State private var selectedStage = AllStages[0]
    @State private var selectedDivision = Division.RFPO
    @State private var missRate = 0.15 // 15% miss rate
    @State private var generateForAllStages = false
    @State private var isGenerating = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Generate realistic test data for development and testing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Quantity") {
                    Stepper("Runs: \(numberOfRuns)", value: $numberOfRuns, in: 10...1000, step: 10)

                    Stepper("Days Back: \(daysBack)", value: $daysBack, in: 1...365)

                    Text("Data will be distributed across \(daysBack) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Configuration") {
                    Toggle("Generate for All Stages", isOn: $generateForAllStages)

                    if !generateForAllStages {
                        Picker("Stage", selection: $selectedStage) {
                            ForEach(AllStages, id: \.code) { stage in
                                Text("\(stage.code) - \(stage.name)").tag(stage)
                            }
                        }
                    }

                    Picker("Division", selection: $selectedDivision) {
                        ForEach(Division.allCases, id: \.self) { div in
                            Text(div.rawValue).tag(div)
                        }
                    }
                }

                Section("Shot Quality") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Miss Rate")
                            Spacer()
                            Text("\(Int(missRate * 100))%")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $missRate, in: 0...0.5, step: 0.05)

                        Text("Higher miss rate = more challenging runs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    if isGenerating {
                        HStack {
                            ProgressView()
                            Text("Generating...")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button {
                            generateTestData()
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Generate Data")
                                Spacer()
                            }
                        }
                    }
                } footer: {
                    if generateForAllStages {
                        Text("Will generate \(numberOfRuns) runs per stage (\(numberOfRuns * AllStages.count) total)")
                    } else {
                        Text("Will generate \(numberOfRuns) runs for \(selectedStage.name)")
                    }
                }
            }
            .navigationTitle("Generate Test Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .disabled(isGenerating)
        }
    }

    private func generateTestData() {
        isGenerating = true

        DispatchQueue.global(qos: .userInitiated).async {
            let calendar = Calendar.current
            let now = Date()

            let stagesToGenerate = generateForAllStages ? AllStages : [selectedStage]

            for stage in stagesToGenerate {
                for _ in 0..<numberOfRuns {
                    // Distribute runs across the date range
                    let dayOffset = -Int.random(in: 0...daysBack)
                    let hourOffset = Int.random(in: 0...23)
                    let minuteOffset = Int.random(in: 0...59)

                    var date = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
                    date = calendar.date(byAdding: .hour, value: hourOffset, to: date) ?? date
                    date = calendar.date(byAdding: .minute, value: minuteOffset, to: date) ?? date

                    // Random time with some variance
                    let baseTime = 2.0 + Double.random(in: -0.3...0.6)
                    let run = StringRun(
                        stageId: stage.code,
                        divisionId: selectedDivision.rawValue,
                        date: date,
                        time: Decimal(baseTime)
                    )

                    // Generate 5 shots with hit/miss pattern
                    var currentTime: Double = 0
                    let firstShotTime = 0.75 + Double.random(in: 0...0.25)
                    var missedTargets: [Int] = []

                    for shotNum in 1...5 {
                        let splitTime = shotNum == 1 ? firstShotTime : (0.3 + Double.random(in: 0...0.35))
                        currentTime += splitTime

                        // Determine hit/miss based on miss rate
                        // Stop plate (target 5) has slightly lower miss rate
                        let adjustedMissRate = shotNum == 5 ? missRate * 0.7 : missRate
                        let isMiss = Double.random(in: 0...1) <= adjustedMissRate

                        if isMiss {
                            missedTargets.append(shotNum)
                        }

                        let shot = StringShot(
                            now: Decimal(currentTime),
                            split: Decimal(splitTime),
                            first: Decimal(firstShotTime)
                        )
                        run.stringShots.append(shot)
                    }

                    // Update run time to last shot
                    run.time = run.stringShots.last?.now ?? 0
                    run.missedTargets = missedTargets

                    DispatchQueue.main.async {
                        modelContext.insert(run)
                    }
                }
            }

            // Save all at once
            DispatchQueue.main.async {
                do {
                    try modelContext.save()
                    isGenerating = false
                    dismiss()
                } catch {
                    print("Error saving test data: \(error)")
                    isGenerating = false
                }
            }
        }
    }
}

#Preview {
    GenerateTestDataView()
        .modelContainer(for: [StringRun.self, ShooterProfile.self])
}
#endif
