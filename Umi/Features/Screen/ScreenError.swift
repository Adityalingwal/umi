nonisolated enum ScreenError: Error {
    case displayNotFound
    case captureFailed
    case encodingFailed
    #if DEBUG
    case replacementImageUnreadable
    #endif
}
