struct MeteredAudioSource: AudioSource {
    let source: any AudioSource
    let cursor: UmiCursor

    func chunks() -> AsyncThrowingStream<AudioChunk, any Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: AudioChunk.self)
        let upstream = source.chunks()
        let forwarding = Task { [cursor] in
            do {
                for try await chunk in upstream {
                    cursor.hear(AudioLevel(chunk))
                    continuation.yield(chunk)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in
            forwarding.cancel()
        }
        return stream
    }
}
