enum ListeningState {
    case resting
    case hearing(AudioLevel)
    case failed(AudioSourceError)
}
