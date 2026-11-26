struct SilenceRule {
    // Aditya's pick from #14's measurements, where the first sound came at most 1.22 s after a Flush; the wait counts
    // from a piece's Flush, or from the connection when the piece was flushed before it.
    private static let waitingLimit = Duration.seconds(3)
    // A guess: connections in the runs of #78 took up to 4.6 s. It counts from the first Flush, so a long hold on a
    // slow connection is not cut before the answer's first piece is flushed.
    private static let connectingLimit = Duration.seconds(10)

    private var isConnected = false
    private var connectingSince: ContinuousClock.Instant?
    private var waitingSince: ContinuousClock.Instant?
    private var lastPlayed = 0

    // True when a piece was already waiting for sound; its wait starts again now.
    mutating func connected() -> Bool {
        isConnected = true
        connectingSince = nil
        guard waitingSince != nil else { return false }
        waitingSince = .now
        return true
    }

    mutating func pieceFlushed() {
        waitingSince = waitingSince ?? .now
        if !isConnected, connectingSince == nil {
            connectingSince = .now
        }
    }

    mutating func check(isSilenceJudged: Bool, played: Int) -> SpeakingError? {
        guard isConnected else {
            guard let connectingSince else { return nil }
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
