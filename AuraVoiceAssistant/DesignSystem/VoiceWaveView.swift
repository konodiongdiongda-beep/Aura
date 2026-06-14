import SwiftUI
import VoiceCore

struct VoiceWaveView: View {
    var state: VoiceCallState
    var audioLevel: Double
    var barCount: Int = 10
    var compact: Bool = false

    private var isActive: Bool {
        switch state {
        case .listening, .recognizing, .speaking, .interrupted:
            return true
        default:
            return false
        }
    }

    private var tint: Color {
        switch state {
        case .speaking:
            return AppColors.secondary
        case .interrupted, .error:
            return AppColors.error
        case .thinking:
            return AppColors.primaryContainer
        default:
            return AppColors.primary
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.06, paused: !isActive)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 6) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.72), tint],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: height(for: index, time: time))
                        .shadow(color: tint.opacity(0.22), radius: 6, x: 0, y: 3)
                        .animation(.easeOut(duration: 0.12), value: audioLevel)
                }
            }
            .frame(height: compact ? 32 : 46)
            .accessibilityLabel("Voice activity waveform")
        }
    }

    private var baseHeight: CGFloat { compact ? 5 : 7 }

    private func height(for index: Int, time: TimeInterval) -> CGFloat {
        guard isActive else { return baseHeight }
        let level = max(0.0, min(1.0, audioLevel))
        // No sound -> stay flat (no vibration).
        guard level > 0.02 else { return baseHeight }

        let peak: CGFloat = compact ? 20 : 30
        // Center bars react more than the edges for an organic envelope.
        let center = Double(barCount - 1) / 2.0
        let distance = center > 0 ? abs(Double(index) - center) / center : 0
        let shape = 1.0 - 0.45 * distance
        // Fast per-bar oscillation modulated by the live audio level.
        let phase = Double(index) * 0.7
        let osc = (sin(time * 7.0 + phase) + 1) / 2
        let dynamic = (0.5 + 0.5 * osc) * level * shape
        return baseHeight + peak * CGFloat(dynamic)
    }
}
