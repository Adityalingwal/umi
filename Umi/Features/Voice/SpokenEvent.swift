enum SpokenEvent {
    case show(String)
    case nameComing(after: Duration)
    case nameStarted
    case nameLineEnded
    case voiceFailed
    case finished
}
