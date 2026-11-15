import Foundation

public enum CalcRateFailure: String, Error, Equatable, Sendable {
    case offline
    case unavailable

    public var text: String {
        TextBlock(fields: [.init(key: "status", value: rawValue)]).text
    }

    init(_ error: Error) {
        let offline: [URLError.Code] = [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff]
        if let failure = error as? CalcRateFailure {
            self = failure
        } else if let error = error as? URLError, offline.contains(error.code) {
            self = .offline
        } else {
            self = .unavailable
        }
    }
}
