import SwiftUI

struct LevelBar: View {
    private static let height = 22.0

    @Environment(Listening.self) private var listening

    var body: some View {
        Group {
            if let message = listening.state.message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LevelTrack(fraction: listening.state.fraction)
                    .opacity(listening.state.isDimmed ? 0.4 : 1)
            }
        }
        .frame(height: Self.height)
        .padding(.horizontal, 14)
    }
}

private struct LevelTrack: View {
    let fraction: Double

    var body: some View {
        Capsule()
            .fill(.quaternary)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule()
                        .fill(.tint)
                        .frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: 6)
            .accessibilityElement()
            .accessibilityLabel("Sound level")
            .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
    }
}

private extension ListeningState {
    var fraction: Double {
        switch self {
        case .hearing(let level): level.fraction
        case .resting, .failed: 0
        }
    }

    var isDimmed: Bool {
        switch self {
        case .failed(.microphoneNotAllowed): true
        case .resting, .hearing, .failed: false
        }
    }

    var message: String? {
        switch self {
        case .resting, .hearing, .failed(.microphoneNotAllowed): nil
        case .failed(.microphoneUnavailable): "Can't start the microphone"
        #if DEBUG
        case .failed(.audioFileUnreadable): "Can't read the audio file"
        #endif
        }
    }
}
