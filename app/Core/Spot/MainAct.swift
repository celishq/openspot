import Foundation

public enum MainAct: Equatable, Sendable {
    case toggle
    case run(closes: Bool)
    case command(String)
    case sheet
    case open(String)
    case none
}
