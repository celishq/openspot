import Foundation

public enum FormAnswer: Equatable, Sendable {
    case done
    case form(ItemForm)
}
