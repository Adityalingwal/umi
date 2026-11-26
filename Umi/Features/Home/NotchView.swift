import SwiftUI

struct NotchView: View {
    private static let motion = Animation.easeOut(duration: 0.2)

    let notchHeight: CGFloat
    @Environment(Notch.self) private var notch

    var body: some View {
        let shape = NotchShape(
            shoulder: NotchPlace.shoulder,
            bottomRadius: notch.isOpen ? NotchPlace.openBottomRadius : NotchPlace.restBottomRadius
        )
        ZStack(alignment: .top) {
            Color.black
            if notch.isOpen {
                DottedPattern()
                ChatView()
                    .padding(.top, notchHeight)
                    .padding(.horizontal, NotchPlace.shoulder)
                    .transition(.opacity)
            }
        }
        .clipShape(shape)
        .animation(Self.motion, value: notch.isOpen)
    }
}
