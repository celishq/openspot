import Foundation

public struct ThemeValues: Equatable, Sendable {
    private var values: [ThemeKey: ConfigDocument.Value] = [:]

    public init() {}

    subscript(id: ThemeKey) -> ConfigDocument.Value? {
        get { values[id] }
        set { values[id] = newValue }
    }

    func colour(_ section: String, _ key: String) -> ThemeColor? {
        guard case .string(let text)? = values[ThemeKey(section: section, key: key)] else { return nil }
        return ThemeColor(text: text)
    }

    func number(_ section: String, _ key: String) -> Double? {
        switch values[ThemeKey(section: section, key: key)] {
        case .number(let number)?: number
        case .integer(let number)?: Double(number)
        default: nil
        }
    }

    func word<Value: RawRepresentable<String>>(_ section: String, _ key: String) -> Value? {
        guard case .string(let text)? = values[ThemeKey(section: section, key: key)] else { return nil }
        return Value(rawValue: text)
    }

    func merging(_ other: ThemeValues) -> ThemeValues {
        var merged = self
        merged.values.merge(other.values) { _, new in new }
        return merged
    }
}
