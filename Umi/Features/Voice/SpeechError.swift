import Foundation

nonisolated enum SpeechError: Error {
    case keyMissing
    case keyRefused
    case noInternet
    case serviceFailed
    case connectionFailed
    case noFinalText

    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet,
        .networkConnectionLost,
        .cannotFindHost,
        .cannotConnectToHost,
        .dnsLookupFailed,
        .timedOut,
        .dataNotAllowed,
        .internationalRoamingOff
    ]

    init(_ error: URLError) {
        self = Self.offlineCodes.contains(error.code) ? .noInternet : .serviceFailed
    }

    init(httpStatus: Int) {
        self = httpStatus == 401 || httpStatus == 403 ? .keyRefused : .serviceFailed
    }
}
