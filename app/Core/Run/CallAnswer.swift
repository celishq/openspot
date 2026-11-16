import Foundation

public enum CallAnswer: Equatable, Sendable {
    case form(ItemForm)
    case shown
    case done
    case stopped
}
