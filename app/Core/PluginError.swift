public enum PluginError: Error, Equatable, Sendable {
    case timedOut
    case failed(Int32)
}
