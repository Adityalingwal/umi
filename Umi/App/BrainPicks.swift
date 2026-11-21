#if DEBUG
import Foundation

final class BrainPicks {
    private let brain: ChosenBrain
    private var picks: [BrainKind]

    private init(brain: ChosenBrain, picks: [BrainKind]) {
        self.brain = brain
        self.picks = picks
    }

    static func atLaunch(defaults: UserDefaults, brain: ChosenBrain) -> BrainPicks? {
        let picks = (defaults.stringArray(forKey: "UmiBrainPicks") ?? []).compactMap(BrainKind.init(rawValue:))
        guard !picks.isEmpty else { return nil }
        return BrainPicks(brain: brain, picks: picks)
    }

    func applied(to holds: AsyncStream<HoldEvent>) -> AsyncStream<HoldEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: HoldEvent.self)
        let forwarding = Task {
            for await hold in holds {
                if case .began = hold, !picks.isEmpty {
                    brain.choose(picks.removeFirst())
                }
                continuation.yield(hold)
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in
            forwarding.cancel()
        }
        return stream
    }
}
#endif
