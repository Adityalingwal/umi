import SwiftUI

struct MarkLabel: View {
    let label: PointLabel
    let travel: Travel

    var body: some View {
        MarkLabelLayout(target: travel.target, arrowTip: travel.arrowTip, ringRadius: Travel.ringDiameter / 2) {
            Text(label.text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.black.opacity(0.55), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
    }
}

private nonisolated struct MarkLabelLayout: Layout {
    private static let gapOutsideRing = 8.0
    private static let screenMargin = 4.0
    private static let arrowReach = 30.0

    let target: CGPoint
    let arrowTip: CGPoint
    let ringRadius: Double

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let frame = frame(of: size, within: bounds)
            subview.place(at: frame.origin, proposal: ProposedViewSize(size))
        }
    }

    private func frame(of size: CGSize, within bounds: CGRect) -> CGRect {
        let screen = bounds.insetBy(dx: Self.screenMargin, dy: Self.screenMargin)
        let mark = CGPoint(x: bounds.minX + target.x, y: bounds.minY + target.y)
        let reach = ringRadius + Self.gapOutsideRing
        let besides = [mark.x + reach, mark.x - reach - size.width].map { left in
            CGRect(origin: CGPoint(x: left, y: mark.y - size.height / 2), size: size).slidVertically(into: screen)
        }
        let belowOrAbove = [mark.y + reach, mark.y - reach - size.height].map { top in
            CGRect(origin: CGPoint(x: mark.x - size.width / 2, y: top), size: size).slidHorizontally(into: screen)
        }
        let sides = besides + belowOrAbove
        let onScreen = sides.filter(screen.contains)
        let arrow = arrowArea(within: bounds)
        return onScreen.first { !$0.intersects(arrow) } ?? onScreen.first
            ?? sides[0].slidHorizontally(into: screen).slidVertically(into: screen)
    }

    private func arrowArea(within bounds: CGRect) -> CGRect {
        let tip = CGPoint(x: bounds.minX + arrowTip.x, y: bounds.minY + arrowTip.y)
        let away = CGVector(dx: arrowTip.x - target.x, dy: arrowTip.y - target.y)
        let length = max(hypot(away.dx, away.dy), 1)
        let middle = CGPoint(
            x: tip.x + away.dx / length * Self.arrowReach / 2,
            y: tip.y + away.dy / length * Self.arrowReach / 2
        )
        return CGRect(
            x: middle.x - Self.arrowReach / 2,
            y: middle.y - Self.arrowReach / 2,
            width: Self.arrowReach,
            height: Self.arrowReach
        )
    }
}

private nonisolated extension CGRect {
    func slidVertically(into area: CGRect) -> CGRect {
        offsetBy(dx: 0, dy: min(max(minY, area.minY), area.maxY - height) - minY)
    }

    func slidHorizontally(into area: CGRect) -> CGRect {
        offsetBy(dx: min(max(minX, area.minX), area.maxX - width) - minX, dy: 0)
    }
}
