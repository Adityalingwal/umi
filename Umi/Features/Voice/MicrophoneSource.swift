struct MicrophoneSource: AudioSource {
    let permission: MicrophonePermission

    func chunks() -> AsyncThrowingStream<AudioChunk, any Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: AudioChunk.self)
        guard permission.currentAccess() == .allowed else {
            continuation.finish(throwing: AudioSourceError.microphoneNotAllowed)
            return stream
        }
        let microphone = MicrophoneEngine()
        let starting = Task {
            await microphone.start(yieldingTo: continuation)
        }
        continuation.onTermination = { _ in
            starting.cancel()
            microphone.stop()
        }
        return stream
    }
}
