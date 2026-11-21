import Foundation

nonisolated enum CodexLine {
    static func request(id: Int, method: String, params: [String: Any]) throws -> Data {
        try encode(["id": id, "method": method, "params": params])
    }

    static func notification(method: String) throws -> Data {
        try encode(["method": method])
    }

    static func refusal(id: Any) throws -> Data {
        try encode(["id": id, "error": ["code": -32_000, "message": "Umi only takes answers"]])
    }

    private static func encode(_ message: [String: Any]) throws -> Data {
        var line = try JSONSerialization.data(withJSONObject: message)
        line.append(UInt8(ascii: "\n"))
        return line
    }
}
