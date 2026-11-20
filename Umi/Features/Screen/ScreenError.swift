nonisolated enum ScreenError: Error {
    case notAllowed
    case needsRelaunch
    case displayNotFound
    case captureFailed
    case encodingFailed
    #if DEBUG
    case replacementImageUnreadable
    #endif
}
