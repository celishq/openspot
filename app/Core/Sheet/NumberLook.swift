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
            if reading.isSeries, rows >= 2, columns >= 2 || reading.max == nil {
                self = .stat
            } else if reading.level != nil {
                self = columns <= rows ? .ring : .bar
            } else if reading.isSeries {
                self = .bar
            } else {
                self = .stat
            }
        }
    }
}
