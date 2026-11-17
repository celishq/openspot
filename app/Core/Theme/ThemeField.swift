import Foundation

struct ThemeField<Part> {
    enum Slot {
        case colour(WritableKeyPath<Part, ThemeColor>)
        case number(WritableKeyPath<Part, Double>)
        case variant(WritableKeyPath<Part, Theme.Glass.Variant>)
    }

    let kind: ThemeKind
    let slot: Slot

    static func colour(_ path: WritableKeyPath<Part, ThemeColor>) -> ThemeField {
        ThemeField(kind: .colour, slot: .colour(path))
    }

    static func number(_ kind: ThemeKind, _ path: WritableKeyPath<Part, Double>) -> ThemeField {
        ThemeField(kind: kind, slot: .number(path))
    }

    static func variant(_ path: WritableKeyPath<Part, Theme.Glass.Variant>) -> ThemeField {
        ThemeField(kind: .variant, slot: .variant(path))
    }

    func on<Whole>(_ part: WritableKeyPath<Whole, Part>) -> ThemeField<Whole> {
        switch slot {
        case .colour(let path): ThemeField<Whole>(kind: kind, slot: .colour(part.appending(path: path)))
        case .number(let path): ThemeField<Whole>(kind: kind, slot: .number(part.appending(path: path)))
        case .variant(let path): ThemeField<Whole>(kind: kind, slot: .variant(part.appending(path: path)))
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
        case .variant(let path):
            guard case .string(let text)? = value, let variant = Theme.Glass.Variant(rawValue: text) else { return false }
            whole[keyPath: path] = variant
        }
        return true
    }
}
