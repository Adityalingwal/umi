import Foundation

struct SpokenTurns {
    private(set) var count = 0
    private(set) var openTurn: Int?
    private var piecesStarted = 0
    private var turnsStarted = 0
    private var turnsWithAudio = 0
    private var turnsEnded = 0

    var isAudioOwed: Bool {
        turnsEnded < count
    }

    var hasStartedPlaying: Bool {
        piecesStarted > 0
    }

    mutating func add() -> Int {
        count += 1
        return count - 1
    }

    mutating func open() -> Int {
        let turn = add()
        openTurn = turn
        return turn
    }

    mutating func close() -> Int? {
        defer { openTurn = nil }
        return openTurn
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
        guard turn < count, turn >= piecesStarted else { return [] }
        let isFirst = piecesStarted == 0
        piecesStarted = turn + 1
        return (isFirst ? [.firstSound] : []) + [.piecesStarted(piecesStarted)]
    }
}
