import OSLog

final class Conversation {
    private static let keptExchanges = 20

    private(set) var exchanges: [Exchange] = []
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Conversation")

    func add(_ exchange: Exchange) {
        guard !exchange.answer.allSatisfy(\.isWhitespace) else {
            logger.notice("No answer text arrived, so the exchange was not kept")
            return
        }
        exchanges.append(exchange)
        if exchanges.count > Self.keptExchanges {
            exchanges.removeFirst(exchanges.count - Self.keptExchanges)
        }
        let characters = exchange.answer.count
        let kept = exchanges.count
        logger.notice("Kept an exchange: \(characters, privacy: .public) answer characters")
        logger.notice("The conversation holds \(kept, privacy: .public) exchanges")
    }
}
