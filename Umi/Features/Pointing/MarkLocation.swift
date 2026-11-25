nonisolated enum MarkLocation: Equatable, Sendable {
    case point(PointLocation)
    case box(BoxLocation)
    case stroke(StrokeLocation)
}
