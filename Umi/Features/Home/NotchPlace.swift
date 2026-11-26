import AppKit

struct NotchPlace {
    static let shoulder = 8.0
    static let restBottomRadius = 9.0
    static let openBottomRadius = 22.0
    private static let chatSize = CGSize(width: 480, height: 440)
    private static let screenWithoutNotchWidth = 180.0

    let notchHeight: CGFloat
    let restFrame: CGRect
    let openFrame: CGRect

    init(screen: NSScreen) {
        let frame = screen.frame
        let notch: CGRect
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let height = screen.safeAreaInsets.top
            notch = CGRect(x: left.maxX, y: frame.maxY - height, width: right.minX - left.maxX, height: height)
        } else {
            let height = NSStatusBar.system.thickness
            notch = CGRect(
                x: frame.midX - Self.screenWithoutNotchWidth / 2,
                y: frame.maxY - height,
                width: Self.screenWithoutNotchWidth,
                height: height
            )
        }
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

    static func notchedScreen(among screens: [NSScreen]) -> NSScreen? {
        screens.first { $0.auxiliaryTopLeftArea != nil } ?? screens.first
    }
}
