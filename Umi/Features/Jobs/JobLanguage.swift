// The brain writes a job's task in the user's language, and Hindi in Devanagari, so the task tells the language.
enum JobLanguage {
    case english
    case hindi

    init(task: String) {
        let isHindi = task.unicodeScalars.contains { (0x0900...0x097F).contains($0.value) }
        self = isHindi ? .hindi : .english
    }
}
