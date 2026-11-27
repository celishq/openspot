import Foundation

public enum Icon: Equatable, Sendable {
    case symbol(String)
    case file(String)
    case image(String)
    case glyph(String)
    case color(String)

    private static let pictures: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "tif", "tiff", "webp", "bmp", "pdf", "icns", "svg"]
    public static let videos: Set<String> = ["mov", "mp4", "m4v"]

    public init?(text: String?) {
        guard let text, !text.isEmpty else { return nil }
        if let hex = Self.hex(of: text) {
            self = .color(hex)
        } else if WebPictures.isWeb(text) || Self.pictures.union(Self.videos).contains((text as NSString).pathExtension.lowercased()) {
            self = .image(text)
        } else if text.contains("/") || text.hasPrefix("~") {
            self = .file(text)
        } else if text.contains(where: \.isLetter), text.allSatisfy({ $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == ".") }) {
            self = .symbol(text)
        } else {
            self = .glyph(text)
        }
    }

    public var symbol: String? {
        if case .symbol(let name) = self { name } else { nil }
    }

    public var file: String? {
        if case .file(let path) = self { path } else { nil }
    }

    public var image: String? {
        if case .image(let path) = self { path } else { nil }
    }

    public var glyph: String? {
        if case .glyph(let text) = self { text } else { nil }
    }

    private static func hex(of text: String) -> String? {
        guard text.first == "#", text.dropFirst().allSatisfy(\.isHexDigit) else { return nil }
        switch text.count {
        case 7: return text
        case 4: return "#" + text.dropFirst().map { "\($0)\($0)" }.joined()
        default: return nil
        }
    }

    public var color: String? {
        if case .color(let hex) = self { hex } else { nil }
    }
}
