import AppKit

struct NotchPlace: Equatable {
    static let shoulder = 8.0
    static let restBottomRadius = 9.0
    static let openBottomRadius = 22.0
    static let chatSize = CGSize(width: 480, height: 440)
    private static let settingsSize = CGSize(width: 640, height: 440)
    private static let reportSize = CGSize(width: 720, height: 560)
    private static let bannerSize = CGSize(width: 420, height: 88)

    let notchHeight: CGFloat
    let bannerFrame: CGRect
    private let notch: CGRect
    private let chatFrame: CGRect
    private let settingsFrame: CGRect
    private let reportFrame: CGRect

    init?(screen: NSScreen) {
        guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return nil }
        let frame = screen.frame
        let height = screen.safeAreaInsets.top
        let notch = CGRect(x: left.maxX, y: frame.maxY - height, width: right.minX - left.maxX, height: height)
        notchHeight = notch.height
        self.notch = notch
        chatFrame = Self.openFrame(of: Self.chatSize, under: notch, on: frame)
        settingsFrame = Self.openFrame(of: Self.settingsSize, under: notch, on: frame)
        reportFrame = Self.openFrame(of: Self.reportSize, under: notch, on: frame)
        let bannerSize = CGSize(width: Self.bannerSize.width, height: Self.bannerSize.height + notch.height)
        bannerFrame = Self.openFrame(of: bannerSize, under: notch, on: frame)
    }

    static func onNotchedScreen(among screens: [NSScreen]) -> NotchPlace? {
        screens.lazy.compactMap(NotchPlace.init).first
    }

    func restFrame(showing word: NotchWord?) -> CGRect {
        notch.insetBy(dx: -Self.shoulder - (word?.wing ?? 0), dy: 0)
    }

    func openFrame(showing content: PanelPage) -> CGRect {
        switch content {
        case .chat: chatFrame
        case .settings: settingsFrame
        case .report: reportFrame
        }
    }

    private static func openFrame(of size: CGSize, under notch: CGRect, on screen: CGRect) -> CGRect {
        let width = size.width + 2 * shoulder
        return CGRect(x: notch.midX - width / 2, y: screen.maxY - size.height, width: width, height: size.height)
    }
}
