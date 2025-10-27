import SwiftUI

struct AudioVisualizerView: View {
    let barCount: Int = 12
    let color: Color

    @State private var barHeights: [CGFloat] = []

    init(color: Color = .orange) {
        self.color = color
    }

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [color.opacity(0.6), color]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 8, height: barHeights[safe: index] ?? 20)
                    .animation(
                        .easeInOut(duration: Double.random(in: 0.3...0.6))
                        .repeatForever(autoreverses: true),
                        value: barHeights[safe: index]
                    )
            }
        }
        .frame(height: 100)
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Initialize with random heights
        barHeights = (0..<barCount).map { _ in CGFloat.random(in: 20...80) }

        // Continuously update heights
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation {
                barHeights = (0..<barCount).map { index in
                    // Create wave-like pattern with some randomness
                    let baseHeight = CGFloat.random(in: 20...80)
                    let waveOffset = sin(Double(index) * 0.5 + Date().timeIntervalSince1970) * 15
                    return max(20, min(80, baseHeight + waveOffset))
                }
            }
        }
    }
}

// Helper extension for safe array access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct PulsingCircleView: View {
    @State private var isPulsing = false
    let color: Color

    init(color: Color = .orange) {
        self.color = color
    }

    var body: some View {
        ZStack {
            // Outer pulse rings
            ForEach(0..<3) { index in
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 2)
                    .frame(width: 80, height: 80)
                    .scaleEffect(isPulsing ? 1.8 : 1.0)
                    .opacity(isPulsing ? 0.0 : 0.8)
                    .animation(
                        .easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.3),
                        value: isPulsing
                    )
            }

            // Center icon with glow
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .blur(radius: 10)

                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [color.opacity(0.8), color]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "waveform")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPulsing ? 1.1 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
        }
        .onAppear {
            isPulsing = true
        }
    }
}

#Preview("Visualizer") {
    VStack(spacing: 40) {
        AudioVisualizerView()
        AudioVisualizerView(color: .blue)
        AudioVisualizerView(color: .green)
    }
    .padding()
}

#Preview("Pulsing Circle") {
    VStack(spacing: 40) {
        PulsingCircleView()
        PulsingCircleView(color: .blue)
    }
    .padding()
}
