import Foundation

public struct ThemeFile: Sendable {
    public static let builtInURL = Bundle.main.url(forResource: "theme", withExtension: "toml", subdirectory: "Themes/openspot.theme")

    public let builtIn: URL?
    public let copy: URL?

    public init(builtIn: URL?, copy: URL? = nil) {
        self.builtIn = builtIn
        self.copy = copy
    }

    public func read() -> Theme {
        guard let builtIn, let text = try? String(contentsOf: builtIn, encoding: .utf8) else {
            return Theme(unreadable: "theme.toml cannot be read. Install Openspot again.")
        }
        let theme = Theme(text: text)
        guard let copy, FileManager.default.fileExists(atPath: copy.path) else { return theme }
        guard let own = try? String(contentsOf: copy, encoding: .utf8) else {
            return Theme(unreadable: "theme.toml cannot be read at \(copy.path), so Openspot keeps the look of the app. Save it as text, or delete it.", over: theme)
        }
        return Theme(text: own, over: theme)
    }
}
