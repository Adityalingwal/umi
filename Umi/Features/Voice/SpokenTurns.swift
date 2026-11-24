import Foundation

struct SpokenTurns {
    private(set) var sentences: [String] = []
    private var turnSentences: [Int] = []
    private var nameTurn: Int?
    private var sentencesShown = 0
    private var turnsStarted = 0
    private var turnsWithAudio = 0
    private var turnsEnded = 0

    var count: Int {
        turnSentences.count
    }

    var isAudioOwed: Bool {
        turnsEnded < turnSentences.count
    }

    mutating func add(_ sentence: String, nameStart: String.Index?) -> [String] {
        let index = sentences.count
        sentences.append(sentence)
        let parts = Self.parts(of: sentence, nameStart: nameStart)
        for (offset, part) in parts.enumerated() where part.isName && nameTurn == nil {
            nameTurn = turnSentences.count + offset
        }
        turnSentences.append(contentsOf: Array(repeating: index, count: parts.count))
        return parts.map(\.text)
    }

    mutating func voiceStartedTurn() {
        turnsStarted += 1
    }

    mutating func audioArrived() -> Int? {
        guard turnsWithAudio < turnsStarted else { return nil }
        turnsWithAudio = turnsStarted
        return turnsStarted - 1
    }

    mutating func voiceEndedTurn() -> Int {
        defer { turnsEnded += 1 }
        return turnsEnded
    }

    func isName(_ turn: Int) -> Bool {
        turn == nameTurn
    }

    func endsNameLine(_ turn: Int) -> Bool {
        guard let nameTurn, turnSentences.indices.contains(nameTurn) else { return false }
        return turnSentences.lastIndex(of: turnSentences[nameTurn]) == turn
    }

    mutating func startPlaying(_ turn: Int) -> [SpokenEvent] {
        guard turnSentences.indices.contains(turn) else { return [] }
        var events: [SpokenEvent] = []
        let sentence = turnSentences[turn]
        if turn == 0 || turnSentences[turn - 1] != sentence {
            sentencesShown = max(sentencesShown, sentence + 1)
            events += [.show(sentences[sentence]), .sentencesShown(sentencesShown)]
        }
        if turn == nameTurn {
            events.append(.nameStarted)
        }
        return events
    }

    private static func isSpoken(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }

    // A Flush just before the name makes the name start its own voice turn, so its first sound is known exactly.
    // A head with no letters or digits could get no turn from the voice, which would shift every later subtitle.
    private static func parts(of sentence: String, nameStart: String.Index?) -> [(text: String, isName: Bool)] {
        guard let nameStart else { return [(sentence, false)] }
        let head = sentence[..<nameStart].trimmingCharacters(in: .whitespacesAndNewlines)
        let tail = sentence[nameStart...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard tail.contains(where: isSpoken) else { return [(sentence, false)] }
        guard head.contains(where: isSpoken) else { return [(sentence, true)] }
        return [(head, false), (tail, true)]
    }
}
