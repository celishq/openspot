import Foundation

public enum NumberLook: Equatable, Sendable {
    case stat
    case ring
    case bar

    public enum Chart: String, Equatable, Sendable {
        case ring, bar
    }

    init(reading: NumberReading, columns: Double, rows: Double) {
        switch reading.chart {
        case .ring: self = .ring
        case .bar: self = .bar
        case nil:
            if reading.isSeries, rows >= 2, columns >= 2 {
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
