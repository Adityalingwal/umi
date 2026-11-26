struct QuestionSources {
    let audio: any AudioSource
    let holds: AsyncStream<HoldEvent>
    let typed: AsyncStream<SentQuestion>
}
