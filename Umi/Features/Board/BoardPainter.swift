import SwiftUI

enum BoardInk {
    static let line = Color(red: 0.25, green: 0.22, blue: 0.38)
    static let label = Color(red: 0.19, green: 0.17, blue: 0.27)
    static let boxFill = Color(red: 0.93, green: 0.92, blue: 0.99)
    static let regionFill = Color.white
    static let noteFill = Color(red: 1.0, green: 0.95, blue: 0.79)
    static let noteLine = Color(red: 0.80, green: 0.58, blue: 0.16)
}

struct BoardPainter {
    private enum SegmentStyle {
        case arrow
        case line
        case leader
    }

    private static let drawDuration = 0.45
    private static let framesPerSecond = 60.0

    let size: CGSize

    static func frameDates(for marks: [ShownMark], after now: Date) -> [Date] {
        guard let last = marks.map(\.appearsAt).max(), last.addingTimeInterval(drawDuration) > now else { return [] }
        let end = last.addingTimeInterval(drawDuration + 1 / framesPerSecond)
        return Array(stride(from: now, through: end, by: 1 / framesPerSecond))
    }

    func draw(_ marks: [ShownMark], in context: GraphicsContext, at date: Date) {
        let canvas = BoardLayout.canvas
        let scale = min(size.width / canvas.width, size.height / canvas.height)
        var surface = context
        surface.translateBy(x: (size.width - canvas.width * scale) / 2, y: (size.height - canvas.height * scale) / 2)
        surface.scaleBy(x: scale, y: scale)
        for shown in marks.sorted(by: { Self.layer(of: $0.mark) < Self.layer(of: $1.mark) }) {
            let progress = Self.progress(of: shown, at: date)
            guard progress > 0 else { continue }
            draw(shown.mark, progress: progress, on: surface)
        }
    }

    private static func layer(of mark: PlacedMark) -> Int {
        switch mark.shape {
        case .region: 0
        case .connector: 1
        case .box: 2
        case .text: 3
        case .note: 4
        }
    }

    private static func progress(of shown: ShownMark, at date: Date) -> Double {
        let linear = min(1, max(0, date.timeIntervalSince(shown.appearsAt) / drawDuration))
        return 1 - pow(1 - linear, 3)
    }

    private func draw(_ mark: PlacedMark, progress: Double, on context: GraphicsContext) {
        switch mark.shape {
        case .box(let frame):
            drawOutline(Path(roundedRect: frame, cornerRadius: 9), fill: BoardInk.boxFill, line: BoardInk.line,
                        progress: progress, on: context)
            drawLabel(mark.label, style: .box, in: frame, progress: progress, on: context)
        case .region(let frame):
            drawOutline(Path(roundedRect: frame, cornerRadius: 12), fill: BoardInk.regionFill,
                        line: BoardInk.line.opacity(0.45), progress: progress, on: context)
            let top = CGRect(x: frame.minX + 10, y: frame.minY + 6, width: frame.width - 20, height: 20)
            drawLabel(mark.label, style: .region, in: top, alignment: .leading, progress: progress, on: context)
        case .text(let frame):
            drawLabel(mark.label, style: .text, in: frame, alignment: .leading, progress: progress, on: context)
        case let .note(frame, leader):
            if let leader {
                drawSegment(leader, style: .leader, progress: progress, on: context)
            }
            drawOutline(Path(roundedRect: frame, cornerRadius: 6), fill: BoardInk.noteFill, line: BoardInk.noteLine,
                        progress: progress, on: context)
            drawLabel(mark.label, style: .note, in: frame, progress: progress, on: context)
        case let .connector(segment, hasHead, labelFrame):
            drawSegment(segment, style: hasHead ? .arrow : .line, progress: progress, on: context)
            if let labelFrame {
                let pill = Path(roundedRect: labelFrame, cornerRadius: labelFrame.height / 2)
                context.fill(pill, with: .color(BoardPaper.color.opacity(progress)))
                drawLabel(mark.label, style: .connector, in: labelFrame, progress: progress, on: context)
            }
        }
    }

    private func drawOutline(_ path: Path, fill: Color, line: Color, progress: Double, on context: GraphicsContext) {
        context.fill(path, with: .color(fill.opacity(progress)))
        context.stroke(path.trimmedPath(from: 0, to: progress), with: .color(line),
                       style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
    }

    private func drawSegment(
        _ segment: BoardSegment, style: SegmentStyle, progress: Double, on context: GraphicsContext
    ) {
        let end = CGPoint(
            x: segment.start.x + (segment.end.x - segment.start.x) * progress,
            y: segment.start.y + (segment.end.y - segment.start.y) * progress
        )
        var path = Path()
        path.move(to: segment.start)
        path.addLine(to: end)
        if style == .arrow, progress > 0.6 {
            let heading = atan2(segment.end.y - segment.start.y, segment.end.x - segment.start.x)
            for side in [-0.5, 0.5] {
                path.move(to: end)
                path.addLine(to: CGPoint(x: end.x - 10 * cos(heading + side), y: end.y - 10 * sin(heading + side)))
            }
        }
        let isLeader = style == .leader
        let stroke = StrokeStyle(lineWidth: isLeader ? 1.4 : 1.8, lineCap: .round, lineJoin: .round,
                                 dash: isLeader ? [4, 4] : [])
        context.stroke(path, with: .color(isLeader ? BoardInk.noteLine : BoardInk.line), style: stroke)
    }

    private func drawLabel(
        _ label: String?, style: BoardLabel.Style, in frame: CGRect, alignment: TextAlignment = .center,
        progress: Double, on context: GraphicsContext
    ) {
        guard let label else { return }
        let opacity = min(1, max(0, (progress - 0.35) / 0.65))
        let text = Text(label)
            .font(BoardLabel.font(style))
            .foregroundStyle(BoardInk.label.opacity(opacity))
        let resolved = context.resolve(text)
        let measured = resolved.measure(in: frame.size)
        let originX = alignment == .leading ? frame.minX : frame.midX - measured.width / 2
        let originY = frame.midY - measured.height / 2
        let box = CGRect(x: originX, y: originY, width: measured.width, height: measured.height)
        context.draw(resolved, in: box)
    }
}
