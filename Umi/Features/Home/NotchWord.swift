// The word the notch shows at rest: while a job works, and after one ended until the panel is next opened.
enum NotchWord: Equatable {
    case working
    case done
    case didNotFinish

    // The notch reaches out this far on each side, for its word and its sign.
    var wing: Double {
        switch self {
        case .working, .done: 64
        case .didNotFinish: 88
        }
    }

    static func atRest(isWorking: Bool, ended: NotchWord?) -> NotchWord? {
        isWorking ? .working : ended
    }
}
