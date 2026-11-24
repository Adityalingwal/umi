import Foundation

struct SpokenTurns {
    private(set) var sentences: [String] = []
    private var sentencesShown = 0
    private var turnsStarted = 0
    private var turnsWithAudio = 0
    private var turnsEnded = 0

    var isAudioOwed: Bool {
        turnsEnded < sentences.count
    }

    mutating func add(_ sentence: String) -> Int {
        sentences.append(sentence)
        return sentences.count - 1
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

    mutating func startPlaying(_ turn: Int) -> [SpokenEvent] {
        guard sentences.indices.contains(turn), turn >= sentencesShown else { return [] }
        sentencesShown = turn + 1
        return [.show(sentences[turn]), .sentencesShown(sentencesShown)]
    }
}
