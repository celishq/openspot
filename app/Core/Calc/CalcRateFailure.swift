import Foundation

/// Why there are no exchange rates: the Mac has no internet, or the source does not answer or answers with no rates. Its
/// raw value is the word of `status=` that `openspot calc solve` prints.
public enum CalcRateFailure: String, Error, Equatable, Sendable {
    case offline
    case unavailable

    /// The line that `openspot calc solve` prints for it.
    public var text: String {
        TextBlock(fields: [.init(key: "status", value: rawValue)]).text
    }

    /// The failure that an error of a download says: no internet for a Mac with no connection, and else a source that is down.
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
