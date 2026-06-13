import SwiftUI
import VoiceCore

struct VoiceWaveView: View {
    var state: VoiceCallState
    var barCount: Int = 10
    var compact: Bool = false

    private var isActive: Bool {
        switch state {
        case .listening, .recognizing, .thinking, .speaking, .interrupted:
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
        TimelineView(.animation(minimumInterval: 0.18, paused: !isActive)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 7) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.72), tint],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 5, height: height(for: index, time: time))
                        .shadow(color: tint.opacity(0.22), radius: 8, x: 0, y: 4)
                }
            }
            .frame(height: compact ? 96 : 132)
            .accessibilityLabel("Voice activity waveform")
        }
    }

    private func height(for index: Int, time: TimeInterval) -> CGFloat {
        guard isActive else { return compact ? 14 : 18 }
        let phase = Double(index) * 0.55
        let base = sin(time * 3.0 + phase)
        let normalized = (base + 1) / 2
        let baseHeight: CGFloat = compact ? 18 : 22
        let peakHeight = compact ? 58 : 82
        return baseHeight + CGFloat(normalized) * CGFloat(peakHeight - (index % 3) * 8)
    }
}
