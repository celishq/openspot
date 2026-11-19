import Foundation

public enum NumberLook: Equatable, Sendable {
    case stat
    case ring
    case bar

    init(reading: NumberReading, named: SpotPart.Look?, columns: Double, rows: Double) {
        switch named {
        case .ring: self = .ring
        case .bar: self = .bar
        default:
            if reading.isSeries {
                self = rows >= 2 ? .stat : .bar
            } else if reading.fill != nil {
                self = columns <= 1 || rows >= 2 ? .ring : .bar
            } else {
                self = .stat
            }
        }
    }
}
