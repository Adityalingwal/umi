import AppKit

struct NotchPlace: Equatable {
    static let shoulder = 8.0
    static let restBottomRadius = 9.0
    static let openBottomRadius = 22.0
    static let chatSize = CGSize(width: 480, height: 440)
    // While a job works, the notch reaches out this far on each side, for its word and its dots.
    static let workingWing = 64.0
    private static let settingsSize = CGSize(width: 640, height: 440)

    let notchHeight: CGFloat
    private let notch: CGRect
    private let chatFrame: CGRect
    private let settingsFrame: CGRect

    init?(screen: NSScreen) {
        guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return nil }
        let frame = screen.frame
        let height = screen.safeAreaInsets.top
        let notch = CGRect(x: left.maxX, y: frame.maxY - height, width: right.minX - left.maxX, height: height)
        notchHeight = notch.height
        self.notch = notch
        chatFrame = Self.openFrame(of: Self.chatSize, under: notch, on: frame)
        settingsFrame = Self.openFrame(of: Self.settingsSize, under: notch, on: frame)
    }

    static func onNotchedScreen(among screens: [NSScreen]) -> NotchPlace? {
        screens.lazy.compactMap(NotchPlace.init).first
    }

    func restFrame(isWorking: Bool) -> CGRect {
        notch.insetBy(dx: -Self.shoulder - (isWorking ? Self.workingWing : 0), dy: 0)
    }

    func openFrame(showing content: HomeContent) -> CGRect {
        switch content {
        case .chat: chatFrame
        case .settings: settingsFrame
        }
    }

    private static func openFrame(of size: CGSize, under notch: CGRect, on screen: CGRect) -> CGRect {
        let width = size.width + 2 * shoulder
        return CGRect(x: notch.midX - width / 2, y: screen.maxY - size.height, width: width, height: size.height)
    }
}
