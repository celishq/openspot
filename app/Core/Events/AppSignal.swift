import Foundation

public enum AppSignal: Equatable, Sendable {
    case panel
    case wake
    case sleep
    case clock
    case query(String)
    case named(String, value: String?, showsEachSpot: Bool = false)
}
