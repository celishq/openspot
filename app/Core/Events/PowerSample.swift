import Foundation

public struct PowerSample: Equatable, Sendable {
    public let source: String
    public let percent: Int?

    public init(source: String, percent: Int?) {
        self.source = source
        self.percent = percent
    }

    public func event(after earlier: PowerSample?) -> SpotEvent? {
        self == earlier ? nil : .named(SpotEvent.powerChange, value: source)
    }
}
