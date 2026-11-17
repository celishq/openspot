import Foundation

struct ThemeField<Part> {
    enum Slot {
        case colour(WritableKeyPath<Part, ThemeColor>)
        case number(WritableKeyPath<Part, Double>)
        case word((inout Part, String) -> Bool)
    }

    let kind: ThemeKind
    let slot: Slot

    static func colour(_ path: WritableKeyPath<Part, ThemeColor>) -> ThemeField {
        ThemeField(kind: .colour, slot: .colour(path))
    }

    static func number(_ kind: ThemeKind, _ path: WritableKeyPath<Part, Double>) -> ThemeField {
        ThemeField(kind: kind, slot: .number(path))
    }

    static func word<Value: RawRepresentable<String>>(_ kind: ThemeKind, _ path: WritableKeyPath<Part, Value>) -> ThemeField {
        ThemeField(kind: kind, slot: .word { part, text in
            guard let value = Value(rawValue: text) else { return false }
            part[keyPath: path] = value
            return true
        })
    }

    func on<Whole>(_ part: WritableKeyPath<Whole, Part>) -> ThemeField<Whole> {
        switch slot {
        case .colour(let path): ThemeField<Whole>(kind: kind, slot: .colour(part.appending(path: path)))
        case .number(let path): ThemeField<Whole>(kind: kind, slot: .number(part.appending(path: path)))
        case .word(let set): ThemeField<Whole>(kind: kind, slot: .word { whole, text in set(&whole[keyPath: part], text) })
        }
    }

    func set(_ value: ConfigDocument.Value?, in whole: inout Part) -> Bool {
        switch slot {
        case .colour(let path):
            guard case .string(let text)? = value, let colour = ThemeColor(text: text) else { return false }
            whole[keyPath: path] = colour
        case .number(let path):
            guard let number = kind.number(value) else { return false }
            whole[keyPath: path] = number
        case .word(let set):
            guard case .string(let text)? = value, set(&whole, text) else { return false }
        }
        return true
    }
}
