import AppKit

struct NotchPlace: Equatable {
    static let shoulder = 8.0
    static let restBottomRadius = 9.0
    static let openBottomRadius = 22.0
    private static let chatSize = CGSize(width: 480, height: 440)

    let notchHeight: CGFloat
    let restFrame: CGRect
    let openFrame: CGRect

    init?(screen: NSScreen) {
        guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return nil }
        let frame = screen.frame
        let height = screen.safeAreaInsets.top
        let notch = CGRect(x: left.maxX, y: frame.maxY - height, width: right.minX - left.maxX, height: height)
        notchHeight = notch.height
        restFrame = notch.insetBy(dx: -Self.shoulder, dy: 0)
        let openWidth = Self.chatSize.width + 2 * Self.shoulder
        openFrame = CGRect(
            x: notch.midX - openWidth / 2,
            y: frame.maxY - Self.chatSize.height,
            width: openWidth,
            height: Self.chatSize.height
        )
    }

    static func onNotchedScreen(among screens: [NSScreen]) -> NotchPlace? {
        screens.lazy.compactMap(NotchPlace.init).first
    }
}
