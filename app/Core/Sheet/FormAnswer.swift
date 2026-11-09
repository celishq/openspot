import Foundation

/// What a script answers to the values of a form: done, or the form again, such as with a line that says what is wrong.
public enum FormAnswer: Equatable, Sendable {
    case done
    case form(ItemForm)
}
