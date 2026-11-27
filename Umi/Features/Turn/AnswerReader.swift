import OSLog

struct AnswerReader {
    private enum Form {
        case undecided
        case spoken
        case drawing
    }

    private let voice: SpokenAnswer
    private let pointing: Pointing?
    private let picture: ScreenPicture
    private let board: Board
    private let jobs: Jobs
    private let written: (String) -> Void
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Turn")
    private var form = Form.undecided
    private var undecidedText = ""
    private var jobTags = JobTagReader()
    private var tags = MarkTagParser()
    private var drawing = DrawingReader()
    private var drawingSpokenText = ""
    private var readText = ""

    var arrivedText: String {
        if case .drawing = form {
            return drawingSpokenText
        }
        var rest = tags
        return rest.finish().reduce(into: readText) { text, part in
            if case .text(let piece) = part {
                text += piece
            }
        }
    }

    init(
        voice: SpokenAnswer,
        pointing: Pointing?,
        picture: ScreenPicture,
        board: Board,
        jobs: Jobs,
        written: @escaping (String) -> Void
    ) {
        self.voice = voice
        self.pointing = pointing
        self.picture = picture
        self.board = board
        self.jobs = jobs
        self.written = written
    }

    mutating func read(_ answer: AsyncThrowingStream<String, any Error>) async throws {
        do {
            var isFirstPiece = true
            for try await piece in answer {
                try Task.checkCancellation()
                if isFirstPiece {
                    isFirstPiece = false
                    logger.notice("The brain's first text arrived")
                }
                try add(jobTags.add(piece))
            }
            try Task.checkCancellation()
            try add(jobTags.finish())
            await actOnJobTag()
            try Task.checkCancellation()
            try finish()
            board.answerRead()
        } catch {
            board.fail()
            throw error
        }
    }

    private mutating func add(_ piece: String) throws {
        switch form {
        case .undecided:
            undecidedText += piece
            guard let first = undecidedText.first(where: { !$0.isWhitespace }) else { return }
            let text = undecidedText
            undecidedText = ""
            if first == "{" {
                form = .drawing
                logger.notice("The answer is a drawing")
                board.expectDrawing()
                try readDrawing(text)
            } else {
                form = .spoken
                readSpoken(text)
            }
        case .spoken:
            readSpoken(piece)
        case .drawing:
            try readDrawing(piece)
        }
    }

    private mutating func finish() throws {
        switch form {
        case .undecided:
            voice.endText()
        case .spoken:
            for part in tags.finish() {
                read(part)
            }
            pointing?.answerTextEnded()
            voice.endText()
        case .drawing:
            drawing.end()
            try useReadyLines()
            board.endReading()
            voice.endText()
        }
    }

    // The job tag is never spoken: Umi says the brain's line once it was done, or why nothing was done.
    private mutating func actOnJobTag() async {
        jobTags.problems.forEach { logger.notice("A job tag was dropped: \(String(describing: $0), privacy: .public)") }
        guard let ask = jobTags.ask else { return }
        guard case .drawing = form else {
            guard let line = await line(after: ask), !Task.isCancelled else { return }
            form = .spoken
            readText += readText.isEmpty ? line : " " + line
            voice.speak(line)
            written(readText)
            return
        }
        logger.notice("A job tag in a drawing answer was dropped")
    }

    private func line(after ask: JobAsk) async -> String? {
        switch ask {
        case .start(let request):
            return await jobs.start(request).line
        case .stop:
            logger.notice("The answer asks to stop the job")
            return ask.line(after: jobs.stop() ? .done : .noJobRunning)
        case .message(let message, _):
            logger.notice("The answer asks to pass a message to the job")
            return ask.line(after: await jobs.send(message))
        }
    }

    private mutating func readDrawing(_ text: String) throws {
        drawing.add(text)
        try useReadyLines()
    }

    private mutating func useReadyLines() throws {
        while let line = try drawing.nextLine() {
            switch line {
            case .newDrawing(let title):
                board.open(title)
            case .edit(let title):
                try board.edit(title)
            case .reopen:
                try board.reopen()
            case let .part(say, marks, removedIDs):
                try board.add(marks, removing: removedIDs)
                voice.speak(say)
                drawingSpokenText += drawingSpokenText.isEmpty ? say : " " + say
                written(drawingSpokenText)
            }
        }
    }

    private mutating func readSpoken(_ text: String) {
        for part in tags.add(text) {
            read(part)
        }
    }

    private mutating func read(_ part: MarkTagParser.Part) {
        switch part {
        case .text(let text):
            readText += text
            voice.stream(text)
            written(readText)
        case let .nameStart(location, label):
            pointing?.aim(at: location, label: label, pictureWidth: picture.width, pictureHeight: picture.height)
        case .dropped(let problem):
            logger.notice("Location data was dropped: \(String(describing: problem), privacy: .public)")
        }
    }
}
