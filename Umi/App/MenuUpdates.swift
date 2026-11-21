#if DEBUG
import Foundation

enum MenuUpdates {
    static func start(defaults: UserDefaults, menu: StatusMenu) -> Task<Void, Never>? {
        let seconds = defaults.integer(forKey: "UmiMenuUpdateEvery")
        guard seconds > 0 else { return nil }
        return Task { [weak menu] in
            while !Task.isCancelled {
                menu?.updateAsIfOpened()
                try? await Task.sleep(for: .seconds(seconds))
            }
        }
    }
}
#endif
