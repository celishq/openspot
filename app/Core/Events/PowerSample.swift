import Foundation

public struct PowerSample: Equatable, Sendable {
    public let source: String
    public let percent: Int?

    public init(source: String, percent: Int?) {
        self.source = source
        self.percent = percent
    }

    public func event(after earlier: PowerSample?) -> AppSignal? {
        self == earlier ? nil : .named(EventName.powerChange, value: source)
    }
}
