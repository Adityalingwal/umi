enum StopReason {
    static func text(for error: any Error) -> String {
        switch error {
        case let error as SpeechError: "speech: \(error)"
        case let error as AudioSourceError: "audio: \(error)"
        case let error as ScreenError: "screen: \(error)"
        case let error as BrainError: "brain: \(error)"
        default: "unexpected"
        }
    }
}
