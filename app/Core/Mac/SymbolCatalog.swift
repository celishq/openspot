import Foundation

/// The symbols of the Character Viewer, with their Unicode names and the titles of their sections, read from the files of the system.
public struct SymbolCatalog: Sendable {
    public static let standardResources = URL(fileURLWithPath: "/System/Library/Input Methods/CharacterPalette.app/Contents/Resources")

    private static let categories = ["Arrows", "Parentheses", "Punctuation", "CurrencySymbols", "Pictographs", "Bullets", "MathematicalSymbols", "LetterlikeSymbols", "TechnicalSymbols", "SignStandardSymbols"]
    private static let codeMark = "0x"
    private static let textMark: Unicode.Scalar = "\u{FE0E}"
    private static let pictureMark: Unicode.Scalar = "\u{FE0F}"
    private static let missing = "This Mac has no symbol lists. Update macOS, or tell the plugin's author."

    private let resources: URL
    private let languages: [String]
    private let keywords: GlyphKeywords

    public init(resources: URL = standardResources, languages: [String] = Locale.preferredLanguages, keywords: GlyphKeywords? = nil) {
        self.resources = resources
        self.languages = languages
        self.keywords = keywords ?? GlyphKeywords(languages: languages)
    }

    /// Each symbol as one row, in the order of the Character Viewer. A symbol in two categories shows once, in the first.
    public func rows() throws -> String {
        let titles = titles()
        var seen: Set<String> = []
        var text = ""
        var found = false
        for category in Self.categories {
            guard let sections = sections(of: category) else { continue }
            found = true
            for (key, list) in sections {
                let subtitle = titles[key ?? "CategoryName-\(category)"]
                for symbol in list.split(separator: ",").map(Self.symbol) where seen.insert(symbol).inserted {
                    guard let name = Self.name(of: symbol) else { continue }
                    var fields: [TextBlock.Field] = [.init(key: "row", value: symbol), .init(key: "title", value: name)]
                    if let subtitle { fields.append(.init(key: "detail", value: subtitle)) }
                    fields += [.init(key: "icon", value: symbol)]
                    fields += keywords.of(symbol).map { .init(key: "keyword", value: $0) }
                    text += TextBlock(fields: fields).text + "\n"
                }
            }
        }
        guard found else { throw PluginError.fault(Self.missing) }
        return text
    }

    /// The sections of a category, each with the key of its title, or none when the category has one list.
    private func sections(of category: String) -> [(String?, String)]? {
        let url = resources.appendingPathComponent("Category-\(category).plist")
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let list = plist["CVCategoryData"] as? [String: Any] else { return nil }
        if let sections = list["DataArray"] as? [[String: String]] {
            return sections.compactMap { section in section["Data"].map { (section["CVDataTitle"], $0) } }
        }
        return (list["Data"] as? String).map { [(nil, $0)] }
    }

    /// The titles of categories and sections in the first language of the Mac that has them.
    private func titles() -> [String: String] {
        guard let data = try? Data(contentsOf: resources.appendingPathComponent("Localizable.loctable")),
              let table = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return [:] }
        return LanguageCodes(languages: languages).all.lazy.compactMap { table[$0] as? [String: String] }.first ?? [:]
    }

    /// The symbol that an item of a list stands for: itself, or the scalar of a code such as `0x2C`.
    private static func symbol(_ item: Substring) -> String {
        guard item.hasPrefix(codeMark), let value = UInt32(item.dropFirst(codeMark.count), radix: 16), let scalar = Unicode.Scalar(value) else { return String(item) }
        return String(scalar)
    }

    /// The Unicode name of a symbol in lower case, with no word for its text or picture form.
    private static func name(of symbol: String) -> String? {
        let names = symbol.unicodeScalars.filter { $0 != textMark && $0 != pictureMark }.compactMap(\.properties.name)
        return names.isEmpty ? nil : names.joined(separator: " ").lowercased()
    }
}
