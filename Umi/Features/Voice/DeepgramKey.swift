import Foundation

nonisolated struct DeepgramKey: Sendable {
    let value: String

    @concurrent
    static func fromBundle(_ bundleURL: URL) async -> DeepgramKey? {
        let fileURL = bundleURL.appending(path: "Contents/Resources/Keys.plist")
        guard let keys = NSDictionary(contentsOf: fileURL),
              let value = keys["DeepgramAPIKey"] as? String,
              !value.isEmpty else {
            return nil
        }
        return DeepgramKey(value: value)
    }
}
