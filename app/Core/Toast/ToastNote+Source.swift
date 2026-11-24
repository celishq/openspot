import Foundation

extension ToastNote {
    struct Source: Equatable, Sendable {
        var words: String?
        var id: String?
        var keeps = false
        var action: String?
        var classes: String?
        var view: String?

        func hiding(_ values: FieldValues) -> Source {
            var hidden = self
            hidden.words = values.hiding(words)
            hidden.view = values.hiding(view)
            return hidden
        }
    }
}
