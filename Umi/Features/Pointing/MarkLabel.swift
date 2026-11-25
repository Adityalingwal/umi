import SwiftUI

struct MarkLabels: View {
    let marks: [ScreenMark]

    var body: some View {
        MarkLabelsLayout {
            ForEach(marks) { mark in
                if let label = mark.label {
                    MarkLabel(text: label.text)
                        .layoutValue(key: LabelledMark.self, value: mark)
                        .transition(.opacity)
                }
            }
        }
    }
}

private struct MarkLabel: View {
    let text: String

    var body: some View {
        Text(text)
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

private nonisolated struct LabelledMark: LayoutValueKey {
    static let defaultValue: ScreenMark? = nil
}

private nonisolated struct MarkLabelsLayout: Layout {
    private static let gapOutsideMark = 8.0
    private static let screenMargin = 4.0
    private static let arrowReach = 30.0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var placed: [CGRect] = []
        for subview in subviews {
            guard let mark = subview[LabelledMark.self] else { continue }
            let size = subview.sizeThatFits(.unspecified)
            let frame = frame(of: size, for: mark, clearOf: placed, within: bounds)
            subview.place(at: frame.origin, proposal: ProposedViewSize(size))
            placed.append(frame)
        }
    }

    private func frame(
        of size: CGSize,
        for mark: ScreenMark,
        clearOf placed: [CGRect],
        within bounds: CGRect
    ) -> CGRect {
        let screen = bounds.insetBy(dx: Self.screenMargin, dy: Self.screenMargin)
        let markFrame = area(of: mark.place, within: bounds)
        let gap = Self.gapOutsideMark
        let besides = [markFrame.maxX + gap, markFrame.minX - gap - size.width].map { left in
            CGRect(origin: CGPoint(x: left, y: markFrame.midY - size.height / 2), size: size)
                .slidVertically(into: screen)
        }
        let belowOrAbove = [markFrame.maxY + gap, markFrame.minY - gap - size.height].map { top in
            CGRect(origin: CGPoint(x: markFrame.midX - size.width / 2, y: top), size: size)
                .slidHorizontally(into: screen)
        }
        let sides = besides + belowOrAbove
        let onScreen = sides.filter(screen.contains)
        let arrow = arrowArea(for: mark, within: bounds)
        let usual = onScreen.filter { !$0.intersects(arrow) }
        let taken = mark.otherMarks.map { area(of: $0, within: bounds) } + placed
        return usual.first { side in !taken.contains(where: side.intersects) } ?? usual.first ?? onScreen.first
            ?? sides[0].slidHorizontally(into: screen).slidVertically(into: screen)
    }

    private func area(of place: MarkPlace, within bounds: CGRect) -> CGRect {
        place.frame.offsetBy(dx: bounds.minX, dy: bounds.minY)
    }

    private func arrowArea(for mark: ScreenMark, within bounds: CGRect) -> CGRect {
        let tip = point(mark.arrowTip, within: bounds)
        let center = mark.place.center
        let away = CGVector(dx: mark.arrowTip.x - center.x, dy: mark.arrowTip.y - center.y)
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

    private func point(_ viewPoint: CGPoint, within bounds: CGRect) -> CGPoint {
        CGPoint(x: bounds.minX + viewPoint.x, y: bounds.minY + viewPoint.y)
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
