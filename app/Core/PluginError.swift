public enum PluginError: Error, Equatable, Sendable {
    case timedOut
    case failed(Int32, String)
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
        case .badState: "It sent a state Openspot cannot read."
        case .badForm: "It sent a form Openspot cannot read."
        case .badMetric: "It sent a metric Openspot cannot read."
        case .fault(let fault): fault
        }
    }
}
