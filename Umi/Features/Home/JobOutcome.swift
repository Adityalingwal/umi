import SwiftUI

// How an ended job reads, the same on its card and on the banner.
struct JobOutcome {
    let title: String
    let symbol: String
    let tint: Color
    let line: String
    let hasReport: Bool

    init?(_ state: Job.State) {
        switch state {
        case .working:
            return nil
        case .done(let result):
            self.init(title: "Done", symbol: "checkmark.circle.fill", tint: .green, line: result, hasReport: true)
        case .failed(let failure):
            self.init(
                title: "Didn't finish", symbol: "exclamationmark.circle.fill", tint: .orange,
                line: failure.reason, hasReport: false
            )
        }
    }

    private init(title: String, symbol: String, tint: Color, line: String, hasReport: Bool) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.line = line
        self.hasReport = hasReport
    }
}
