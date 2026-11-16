import Foundation

public struct ThemeFile: Sendable {
    public static let builtIn = ThemeFile(url: Bundle.main.url(forResource: "theme", withExtension: "toml", subdirectory: "Themes/openspot.theme"))

    public let url: URL?

    public init(url: URL?) {
        self.url = url
    }

    public func read() -> Theme {
        guard let url, let text = try? String(contentsOf: url, encoding: .utf8) else {
            return Theme(unreadable: "theme.toml cannot be read. Install Openspot again.")
        }
        return Theme(text: text)
    }
}
