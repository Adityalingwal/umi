import Foundation

// One plain JSON record per job, in the job's folder beside its work folder, where the job itself cannot write.
nonisolated struct JobRecords: Sendable {
    struct Reading: Sendable {
        var jobs: [Job] = []
        var setAside: [UUID] = []
        var unreadable: [UUID] = []
    }

    static let recordName = "job.json"
    static let setAsideName = "job-unreadable.json"

    private let folder: URL

    init(folder: URL) {
        self.folder = folder
    }

    // Newest first. A folder without a record (a job that never started) is not a job.
    @concurrent
    func read() async throws -> Reading {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: folder.path) else { return Reading() }
        var reading = Reading()
        for jobFolder in try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            guard let id = UUID(uuidString: jobFolder.lastPathComponent) else { continue }
            let record = jobFolder.appending(path: Self.recordName)
            guard fileManager.fileExists(atPath: record.path) else { continue }
            do {
                let saved = try Self.decoder.decode(Record.self, from: Data(contentsOf: record))
                reading.jobs.append(try saved.job(id: id))
            } catch {
                if setAside(record, fileManager: fileManager) {
                    reading.setAside.append(id)
                } else {
                    reading.unreadable.append(id)
                }
            }
        }
        reading.jobs.sort { ($0.startedAt, $0.id.uuidString) > ($1.startedAt, $1.id.uuidString) }
        return reading
    }

    @concurrent
    func write(_ job: Job) async throws {
        let data = try Self.encoder.encode(Record(job))
        let jobFolder = folder.appending(path: job.id.uuidString)
        try FileManager.default.createDirectory(at: jobFolder, withIntermediateDirectories: true)
        try data.write(to: jobFolder.appending(path: Self.recordName), options: .atomic)
    }

    // Nothing set aside is ever deleted: with the name taken, the move fails and the record stays where it is.
    private func setAside(_ record: URL, fileManager: FileManager) -> Bool {
        let setAsideFile = record.deletingLastPathComponent().appending(path: Self.setAsideName)
        do {
            try fileManager.moveItem(at: record, to: setAsideFile)
            return true
        } catch {
            return false
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// The report and the files are named by paths inside the job's own folder, never by a path of this Mac.
private nonisolated struct Record: Codable {
    enum State: String, Codable {
        case working
        case done
        case stopped
        case didNotFinish
    }

    struct Step: Codable {
        let text: String
        let isDone: Bool
    }

    enum FileKind: String, Codable {
        case document
        case other
    }

    struct File: Codable {
        let path: String
        let kind: FileKind
    }

    let name: String
    let task: String
    let state: State
    let result: String?
    let failure: String?
    let started: Date
    let ended: Date?
    let steps: [Step]
    let messages: [String]
    let report: String?
    let files: [File]

    init(_ job: Job) {
        name = job.name
        task = job.task
        started = job.startedAt
        ended = job.endedAt
        steps = job.steps.map { Step(text: $0.text, isDone: $0.isDone) }
        messages = job.messages
        files = job.files.map { File(path: Self.path(of: $0.name), kind: $0.kind == .document ? .document : .other) }
        let reportPath = Self.path(of: JobInstructions.reportName)
        switch job.state {
        case .working: (state, result, failure, report) = (.working, nil, nil, nil)
        case .done(let line): (state, result, failure, report) = (.done, line, nil, reportPath)
        case .stopped: (state, result, failure, report) = (.stopped, nil, nil, nil)
        case .failed(let reason): (state, result, failure, report) = (.didNotFinish, nil, reason.rawValue, nil)
        }
    }

    func job(id: UUID) throws -> Job {
        Job(
            id: id,
            name: name,
            task: task,
            startedAt: started,
            endedAt: ended,
            steps: steps.map { JobStep(text: $0.text, isDone: $0.isDone) },
            messages: messages,
            state: try jobState(),
            files: try files.map { file in
                JobFile(name: try Self.name(in: file.path), kind: file.kind == .document ? .document : .other)
            }
        )
    }

    private func jobState() throws -> Job.State {
        switch state {
        case .working: return .working
        case .stopped: return .stopped
        case .done:
            guard let result else { throw CocoaError(.fileReadCorruptFile) }
            return .done(result: result)
        case .didNotFinish:
            guard let reason = failure.flatMap(JobFailure.init(rawValue:)) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return .failed(reason)
        }
    }

    private static func path(of name: String) -> String {
        "\(ClaudeJobRunner.workFolderName)/\(name)"
    }

    // A file the job made is directly in its work folder, so any other path is not one this record wrote.
    private static func name(in path: String) throws -> String {
        let prefix = "\(ClaudeJobRunner.workFolderName)/"
        let name = path.dropFirst(prefix.count)
        guard path.hasPrefix(prefix), !name.isEmpty, !name.contains("/"), name != "..", name != "." else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return String(name)
    }
}
