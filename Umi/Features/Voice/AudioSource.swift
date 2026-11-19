enum ListeningSchedule {
    case whileMenuIsOpen
    case fromLaunch
}

protocol AudioSource {
    var schedule: ListeningSchedule { get }

    func chunks() -> AsyncThrowingStream<AudioChunk, any Error>
}
