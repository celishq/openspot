import Foundation

public enum MainAct: Equatable, Sendable {
    case toggle
    case command(String)
    case sheet
    case none
}
