import OSLog

extension Speaker {
    func typedAnswer(readsAloud: Bool) -> SpokenAnswer {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Turn")
        guard readsAloud else {
            logger.notice("Read aloud is off: the typed answer is text only")
            return .silent()
        }
        do {
            return try answer()
        } catch {
            let reason = StopReason.text(for: error)
            logger.error("No voice for the typed answer, so it is text only: \(reason, privacy: .public)")
            return .silent()
        }
    }
}
