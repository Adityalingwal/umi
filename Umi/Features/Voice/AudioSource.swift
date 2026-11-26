protocol AudioSource {
    func chunks() -> AsyncThrowingStream<AudioChunk, any Error>
}
