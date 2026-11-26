struct AskedQuestion {
    let id: ChatMessage.ID
    let way: ChatMessage.Way

    // Only a typed question shows its failure in the chat; a spoken one only speaks it.
    var failureShownUnder: ChatMessage.ID? {
        way == .typed ? id : nil
    }
}
