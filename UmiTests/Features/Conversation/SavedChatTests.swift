import Foundation
import Testing
@testable import Umi

struct SavedChatTests {
    @Test func theSavedChatComesBackInOrderAfterAReloadAndClearChatEmptiesIt() async throws {
        let folder = URL.temporaryDirectory.appending(path: "umi-saved-chat-\(UUID().uuidString)")
        let first = Conversation(file: ChatFile(folder: folder))
        await first.load()
        let spoken = first.addQuestion("Which key opens the lid?", way: .spoken)
        first.writeAnswer("The blue one.", to: spoken)
        first.endAnswer(to: spoken)
        let typed = first.addQuestion("And the drawer?", way: .typed)
        first.writeAnswer("The red one.", to: typed)
        first.endAnswer(to: typed)
        await first.saved()

        let second = Conversation(file: ChatFile(folder: folder))
        await second.load()

        #expect(second.messages.map(\.text) == [
            "Which key opens the lid?", "The blue one.", "And the drawer?", "The red one."
        ])
        #expect(second.messages.map(\.author) == [.user, .umi, .user, .umi])
        #expect(second.messages.map(\.way) == [.spoken, .spoken, .typed, .typed])

        second.clear()
        await second.saved()
        let third = Conversation(file: ChatFile(folder: folder))
        await third.load()

        #expect(third.messages.isEmpty)
        try FileManager.default.removeItem(at: folder)
    }
}
