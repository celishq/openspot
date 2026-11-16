import Foundation

public struct ThemeFile: Sendable {
    public static let builtInURL = Bundle.main.url(forResource: "theme", withExtension: "toml", subdirectory: "Themes/openspot.theme")

    public let builtIn: URL?
    public let copy: URL?

    public init(builtIn: URL?, copy: URL? = nil) {
        self.builtIn = builtIn
        self.copy = copy
    }

    public static func standard(environment: [String: String], builtIn: URL? = builtInURL) -> ThemeFile {
        let folder = ConfigFile.standard(environment: environment).url.deletingLastPathComponent()
        return ThemeFile(builtIn: builtIn, copy: folder.appendingPathComponent("themes/openspot.theme/theme.toml"))
    }

    public func read() -> Theme {
        let url = copy.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil } ?? builtIn
        guard let url, let text = try? String(contentsOf: url, encoding: .utf8) else {
            return Theme(unreadable: "theme.toml cannot be read. Install Openspot again.")
        }
        return Theme(text: text)
    }

    public func makeCopy() throws -> URL {
        guard let copy else { throw SpotError.fault("This copy of Openspot has no place for a theme.") }
        guard !FileManager.default.fileExists(atPath: copy.path) else { return copy }
        guard let builtIn else { throw SpotError.fault("theme.toml cannot be read. Install Openspot again.") }
        try FileManager.default.createDirectory(at: copy.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: builtIn, to: copy)
        return copy
    }
}
