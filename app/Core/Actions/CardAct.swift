import Foundation

public enum CardAct: String, Equatable, Sendable, CaseIterable {
    case edit
    case prompt
    case share
    case delete
}
