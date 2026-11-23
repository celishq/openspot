import Foundation

public enum WebAnswer: Equatable, Sendable {
    public enum Cause: String, Sendable {
        case offline, timeout, limit, refused, unavailable
    }

    case answered(status: Int, url: String, headers: [String: String], body: String)
    case failed(Cause, String)

    var script: [String: Any] {
        switch self {
        case .answered(let status, let url, let headers, let body): ["status": status, "url": url, "headers": headers, "body": body]
        case .failed(let cause, let message): ["error": cause.rawValue, "message": message]
        }
    }
}
