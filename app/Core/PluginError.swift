import Foundation

public enum PluginError: Error, Equatable, Sendable {
    case timedOut
    case failed(Int32, String)
    /// A failure whose output names a link that opens its fix (R9).
    case failedWithFix(Int32, String, URL)
    case badState
    case badForm
    case badMetric
    case fault(String)

    /// Why it failed, in words for the person.
    public var reason: String {
        switch self {
        case .timedOut: "It took too long."
        case .failed(let code, ""): "It stopped with code \(code)."
        case .failed(_, let message): message
        case .failedWithFix(let code, let message, _): PluginError.failed(code, message).reason
        case .badState: "It sent a state Openspot cannot read."
        case .badForm: "It sent a form Openspot cannot read."
        case .badMetric: "It sent a metric Openspot cannot read."
        case .fault(let fault): fault
        }
    }
}
