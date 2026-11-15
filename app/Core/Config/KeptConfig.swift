import Foundation

public struct KeptConfig: Equatable, Sendable {
    public let config: Config
    let stamp: String

    public init(config: Config = Config(), stamp: String = "") {
        self.config = config
        self.stamp = stamp
    }
}
