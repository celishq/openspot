import Foundation

/// The picture that one `icon=` value names. An https URL or a path of a picture file, such as `cups.png`, draws the
/// picture. Any other value with a slash, or that starts with `~`, is a file that draws its Finder icon. A name of lowercase
/// letters, digits and dots is an SF Symbol. Any other text, such as an emoji, is drawn as it is.
public enum Icon: Equatable, Sendable {
    case symbol(String)
    case file(String)
    case image(String)
    case glyph(String)

    private static let pictures: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "tif", "tiff", "webp", "bmp", "pdf", "icns", "svg"]

    public init?(text: String?) {
        guard let text, !text.isEmpty else { return nil }
        if WebPictures.isWeb(text) || Self.pictures.contains((text as NSString).pathExtension.lowercased()) {
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
}
