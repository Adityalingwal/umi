import SwiftUI

// It sits beside the job's name, where nothing takes its place when the card turns to the job's end.
struct JobStopButton: View {
    let stop: () -> Void

    var body: some View {
        Button(action: stop) {
            Image(systemName: "stop.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 22, height: 22)
                .background(.white.opacity(0.14), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Stop the job")
        .accessibilityLabel("Stop")
    }
}
