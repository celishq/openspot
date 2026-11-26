import Foundation

public struct Peek: Equatable, Sendable {
    public enum Look: Equatable, Sendable {
        case picture(String)
        case file(String)
        case text(String)
        case link(String, host: String?)
        case color(String)
    }

    static let pictureKinds: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "tiff", "webp", "bmp"]

    public let run: String
    public let look: Look
    public let title: String
    public let caption: String?

    public init?(item: SpotItem) {
        let value = { (key: String) in item.fields.first { $0.key == key && !$0.value.isEmpty }?.value }
        let look: Look
        if let url = value("url") {
            look = .link(url, host: URL(string: url)?.host())
        } else if let color = item.color {
            look = .color(color)
        } else if let file = value("text") == nil ? item.file : nil {
            look = Self.pictureKinds.contains((file as NSString).pathExtension.lowercased()) ? .picture(file) : .file(file)
        } else if let text = value("text") {
            look = .text(text)
        } else {
            return nil
        }
        run = item.run
        self.look = look
        title = item.title
        caption = item.subtitle
    }
}
