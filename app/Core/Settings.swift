import Foundation

/// The Settings spot, which ships with the app. It answers the calls a sheet script answers, in Swift.
public struct Settings: Equatable, Sendable {
    private static let panelKey = "panel_key"

    public let file: ConfigFile
    public let login: LoginItem?

    public init(file: ConfigFile, login: LoginItem? = nil) {
        self.file = file
        self.login = login
    }

    /// Answers one call with the text a script would print. A change prints nothing, which asks for a new read.
    public func answer(_ arguments: [String]) throws -> String {
        switch arguments.first {
        case "read":
            let keyRow = "recents=false\n\naction=open\ntitle=Change\nclose=false\n\nrow=Open Openspot\nrun=\(Self.panelKey)\nsymbol=keyboard\nshortcut=\((file.read().panelKey ?? .standard).text)\n"
            return keyRow + (login.map { "\n" + $0.row.text } ?? "")
        case "open" where arguments.dropFirst().first == LoginItem.run:
            try login?.toggle()
            return ""
        case Self.panelKey:
            guard let shortcut = arguments.dropFirst().first.flatMap(Shortcut.init(text:)) else {
                throw PluginError.failed(1, "Openspot cannot use this key.")
            }
            try file.set(Self.panelKey, to: shortcut.text)
            return ""
        default:
            throw PluginError.failed(1, "Settings cannot do that.")
        }
    }
}
