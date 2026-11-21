import Foundation

// Only the file's metadata is read, never its contents.
nonisolated struct CodexLoginStamp: Equatable, Sendable {
    private let device: Int32
    private let inode: UInt64
    private let modifiedSeconds: Int
    private let modifiedNanoseconds: Int

    init?(of file: URL) {
        var info = stat()
        guard stat(file.path, &info) == 0 else { return nil }
        device = info.st_dev
        inode = info.st_ino
        modifiedSeconds = info.st_mtimespec.tv_sec
        modifiedNanoseconds = info.st_mtimespec.tv_nsec
    }
}
