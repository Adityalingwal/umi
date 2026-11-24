import Foundation
import Observation

@Observable
final class Subtitles {
    private static let lingerAfterEnd = Duration.seconds(1.5)

    private(set) var line: String?

    @ObservationIgnored private var fading: Task<Void, Never>?

    func show(_ text: String) {
        fading?.cancel()
        line = text
    }

    func finish() {
        fading?.cancel()
        fading = Task { [weak self] in
            try? await Task.sleep(for: Self.lingerAfterEnd)
            guard !Task.isCancelled else { return }
            self?.line = nil
        }
    }

    func clear() {
        fading?.cancel()
        line = nil
    }
}
