import Foundation

/// The emoji of this Mac, with their names in its language and their order, read from the files of the system.
public struct EmojiCatalog: Sendable {
    public enum Tone: String, Sendable, CaseIterable {
        case none
        case light
        case mediumLight = "medium-light"
        case medium
        case mediumDark = "medium-dark"
        case dark

        /// The mark that follows a person in an emoji.
        var mark: Unicode.Scalar? {
            switch self {
            case .none: nil
            case .light: "\u{1F3FB}"
            case .mediumLight: "\u{1F3FC}"
            case .medium: "\u{1F3FD}"
            case .mediumDark: "\u{1F3FE}"
            case .dark: "\u{1F3FF}"
            }
        }
    }

    public static let standardResources = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/CoreEmoji.framework/Versions/A/Resources")

    private static let regionMark = "@"
    private static let handshake: Unicode.Scalar = "\u{1F91D}"
    private static let pictureMark: Unicode.Scalar = "\u{FE0F}"
    private static let missing = "This Mac has no emoji names. Update macOS, or tell the spot's author."

    private let resources: URL
    private let languages: [String]
    private let keywords: GlyphKeywords

    public init(resources: URL = standardResources, languages: [String] = Locale.preferredLanguages, keywords: GlyphKeywords? = nil) {
        self.resources = resources
        self.languages = languages
        self.keywords = keywords ?? GlyphKeywords(languages: languages)
    }

    /// Each emoji as one row, in the order of the Mac. An emoji with no form in this tone stays as it is.
    public func rows(tone: Tone) throws -> String {
        let names = try self.names()
        let known = known()
        let place = Dictionary(known.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let sorted = names.keys
            .filter { !$0.contains(Self.regionMark) }
            .sorted { (place[$0] ?? Int.max, $0) < (place[$1] ?? Int.max, $1) }
        var text = ""
        for emoji in sorted {
            let form = Self.form(of: emoji, tone: tone, known: place)
            let row = TextBlock(fields: [
                .init(key: "row", value: form),
                .init(key: "title", value: names[emoji] ?? emoji),
                .init(key: "icon", value: form)
            ] + keywords.of(emoji).map { .init(key: "keyword", value: $0) })
            text += row.text + "\n"
        }
        return text
    }

    private func names() throws -> [String: String] {
        for folder in LanguageCodes(languages: languages).all {
            let url = resources.appendingPathComponent("\(folder).lproj/AppleName.strings")
            guard let data = try? Data(contentsOf: url) else { continue }
            if let names = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] { return names }
        }
        throw SpotError.fault(Self.missing)
    }

    /// Each form that the Mac can draw, in its order: the text runs of a binary file.
    private func known() -> [String] {
        guard let data = try? Data(contentsOf: resources.appendingPathComponent("emojimeta.dat")) else { return [] }
        return String(decoding: data, as: UTF8.self).unicodeScalars
            .split { $0.value < 0x20 || (0x7F...0x9F).contains($0.value) || $0 == "\u{FFFD}" }
            .map { String(String.UnicodeScalarView($0)) }
    }

    /// Puts the mark after each person of an emoji. The hands of a pair take none, and a mark that asks for a picture goes.
    private static func form(of emoji: String, tone: Tone, known: [String: Int]) -> String {
        guard let mark = tone.mark, emoji.unicodeScalars.contains(where: \.properties.isEmojiModifierBase) else { return emoji }
        let scalars = emoji.unicodeScalars
        var toned = String.UnicodeScalarView()
        for scalar in scalars where scalar != pictureMark {
            toned.append(scalar)
            if scalar.properties.isEmojiModifierBase, scalar != handshake || scalars.count == 1 { toned.append(mark) }
        }
        let form = String(toned)
        if known[form] != nil { return form }
        let withPicture = form + String(pictureMark)
        return known[withPicture] != nil ? withPicture : emoji
    }
}
