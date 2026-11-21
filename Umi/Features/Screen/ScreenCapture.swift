import CoreGraphics
import Foundation
import ImageIO
import OSLog
import ScreenCaptureKit

nonisolated struct ScreenCapture: Sendable {
    private let ownBundleID: String?
    private let probe: ScreenAccessProbe?
    private let replacementImageURL: URL?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Screen")

    private init(ownBundleID: String?, probe: ScreenAccessProbe?, replacementImageURL: URL?) {
        self.ownBundleID = ownBundleID
        self.probe = probe
        self.replacementImageURL = replacementImageURL
    }

    static func atLaunch(defaults: UserDefaults, bundle: Bundle) -> ScreenCapture {
        var replacementImageURL: URL?
        #if DEBUG
        replacementImageURL = defaults.string(forKey: "UmiScreenImage").map { URL(filePath: $0) }
        #endif
        return ScreenCapture(
            ownBundleID: bundle.bundleIdentifier,
            probe: bundle.executableURL.map(ScreenAccessProbe.init),
            replacementImageURL: replacementImageURL
        )
    }

    var isAllowed: Bool {
        replacementImageURL != nil || CGPreflightScreenCaptureAccess()
    }

    @concurrent
    func picture(ofDisplay displayID: CGDirectDisplayID) async throws -> ScreenPicture {
        #if DEBUG
        if let replacementImageURL {
            return try replacementPicture(from: replacementImageURL)
        }
        #endif
        guard CGPreflightScreenCaptureAccess() else {
            throw await refusal()
        }
        try Task.checkCancellation()
        let image = try await capture(displayID: displayID)
        logger.notice("Screen captured, \(image.width, privacy: .public)x\(image.height, privacy: .public)")
        try Task.checkCancellation()
        return ScreenPicture(jpegData: try JPEGEncoder.encode(image), width: image.width, height: image.height)
    }

    func refusal() async -> ScreenError {
        await probe?.isGrantedNow() == true ? .needsRelaunch : .notAllowed
    }

    private func capture(displayID: CGDirectDisplayID) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw ScreenError.displayNotFound
        }
        let ownApps = content.applications.filter { $0.bundleIdentifier == ownBundleID }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        try Task.checkCancellation()
        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            logger.error("Screen capture failed: \(error.localizedDescription)")
            throw ScreenError.captureFailed
        }
    }

    #if DEBUG
    private func replacementPicture(from fileURL: URL) throws -> ScreenPicture {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ScreenError.replacementImageUnreadable
        }
        logger.notice("Using the replacement screen image")
        try Task.checkCancellation()
        return ScreenPicture(jpegData: try JPEGEncoder.encode(image), width: image.width, height: image.height)
    }
    #endif
}
