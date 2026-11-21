enum SpokenEvent {
    case show(String)
    case sentencesShown(Int)
    case nameComing(after: Duration)
    case nameStarted
    case nameLineEnded
    case nameShown
    case voiceFailed
    case finished
}
