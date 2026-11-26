struct SilenceRule {
    // Aditya's pick from #14's measurements, where the first sound came at most 1.22 s after a Flush; the wait counts
    // from a piece's Flush, or from the connection when the piece was sent before it.
    private static let waitingLimit = Duration.seconds(3)
    // A guess: connections in the runs of #78 took up to 4.6 s.
    private static let connectingLimit = Duration.seconds(10)

    private var connectingSince: ContinuousClock.Instant?
    private var waitingSince: ContinuousClock.Instant?
    private var lastPlayed = 0

    mutating func startConnecting() {
        connectingSince = .now
    }

    // True when a piece was already waiting for sound; its wait starts again now.
    mutating func connected() -> Bool {
        connectingSince = nil
        guard waitingSince != nil else { return false }
        waitingSince = .now
        return true
    }

    mutating func pieceFlushed() {
        waitingSince = .now
    }

    mutating func check(isSilenceJudged: Bool, played: Int) -> SpeakingError? {
        if let connectingSince {
            return connectingSince.duration(to: .now) < Self.connectingLimit ? nil : .notConnected
        }
        defer { lastPlayed = played }
        if !isSilenceJudged {
            waitingSince = nil
        } else if let since = waitingSince, played == lastPlayed {
            return since.duration(to: .now) < Self.waitingLimit ? nil : .noSound
        } else {
            waitingSince = .now
        }
        return nil
    }
}
