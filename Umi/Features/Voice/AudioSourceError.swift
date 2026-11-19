nonisolated enum AudioSourceError: Error {
    case microphoneNotAllowed
    case microphoneUnavailable
    #if DEBUG
    case audioFileUnreadable
    #endif
}
