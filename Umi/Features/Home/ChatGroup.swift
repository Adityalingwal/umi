import Foundation

struct ChatGroup: Identifiable {
    private static let longestGap: TimeInterval = 5 * 60

    let id: ChatMessage.ID
    let time: Date
    private(set) var messages: [ChatMessage]

    static func groups(of messages: [ChatMessage]) -> [ChatGroup] {
        var groups: [ChatGroup] = []
        for message in messages {
            if let last = groups.last?.messages.last, message.time.timeIntervalSince(last.time) <= longestGap {
                groups[groups.count - 1].messages.append(message)
            } else {
                groups.append(ChatGroup(id: message.id, time: message.time, messages: [message]))
            }
        }
        return groups
    }

    func timeText(now: Date, calendar: Calendar) -> String {
        let clock = time.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(time, inSameDayAs: now) {
            return "Today \(clock)"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(time, inSameDayAs: yesterday) {
            return "Yesterday \(clock)"
        }
        return time.formatted(date: .abbreviated, time: .shortened)
    }
}
