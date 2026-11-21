enum UmiLine {
    static let couldNotHear = "Couldn't hear you, say it again"

    private static let noInternet = "No internet. Check your connection and try again."
    private static let somethingWentWrong = "Something went wrong. Please try again."

    // The voice needs the same internet and the same Deepgram service, so these lines are only shown.
    static func isSpoken(_ error: any Error) -> Bool {
        switch error {
        case is SpeechError, BrainError.noInternet: false
        default: true
        }
    }

    static func failure(_ error: any Error) -> String {
        switch error {
        case let error as SpeechError: speech(error)
        case let error as AudioSourceError: audio(error)
        case let error as ScreenError: screen(error)
        case let error as BrainError: brain(error)
        default: somethingWentWrong
        }
    }

    private static func speech(_ error: SpeechError) -> String {
        switch error {
        case .keyMissing: "The Deepgram key is missing. Add it to .env and rebuild Umi."
        case .keyRefused: "Deepgram didn't accept the key. Check the key in .env and rebuild Umi."
        case .noInternet: noInternet
        case .serviceFailed, .connectionFailed, .noFinalText: "Deepgram isn't answering right now. Please try again."
        }
    }

    private static func audio(_ error: AudioSourceError) -> String {
        switch error {
        case .microphoneNotAllowed: "Umi can't use the microphone. Allow it from Umi's menu or System Settings."
        case .microphoneUnavailable: "The microphone didn't start. Check your input device and try again."
        #if DEBUG
        case .audioFileUnreadable: somethingWentWrong
        #endif
        }
    }

    private static func screen(_ error: ScreenError) -> String {
        switch error {
        case .notAllowed: "Umi can't see your screen. Allow Screen Recording from Umi's menu or System Settings."
        case .needsRelaunch: "Screen Recording is on, but Umi needs a relaunch. Quit Umi and open it again."
        default: "Umi couldn't take a picture of your screen. Please try again."
        }
    }

    private static func brain(_ error: BrainError) -> String {
        switch error {
        case .notInstalled(.claude): "Claude Code isn't installed. Install it, then sign in with claude auth login."
        case .notInstalled(.codex): "Codex isn't installed. Install it, then sign in with codex login."
        case .notSignedIn(.claude): "Claude Code isn't signed in. Run claude auth login in Terminal."
        case .notSignedIn(.codex): "Codex isn't signed in with ChatGPT. Run codex login in Terminal."
        case .limitReached(.claude): "Your Claude usage limit is reached. Try again after it resets."
        case .limitReached(.codex): "Your Codex usage limit is reached. Try again after it resets."
        case .noInternet: noInternet
        case .codexCannotUseModel: "Your Codex account can't use GPT-6.2-Sol, so Codex can't answer."
        case .didNotStart(let brain), .failed(let brain), .answerEndedEarly(let brain):
            "\(brain.title) couldn't answer this time. Please try again."
        }
    }
}
