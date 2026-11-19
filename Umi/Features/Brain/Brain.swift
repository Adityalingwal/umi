protocol Brain {
    func answer(_ question: BrainQuestion) -> AsyncThrowingStream<String, any Error>
}
