import XCTest
@testable import OpenspotCore

@MainActor
class ContextCase: PanelCase {
    var client: URL!

    override func setUp() async throws {
        try await super.setUp()
        client = folder.appendingPathComponent("A.app/Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: client)
        takeCalls()
        host.frontApp = "com.apple.Safari"
    }

    func path(_ name: String) -> String {
        folder.appendingPathComponent(name).path
    }

    func log(_ name: String) -> [String] {
        ((try? String(contentsOfFile: path(name), encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    func source(_ name: String = "tab", app: String? = "^com\\.apple\\.Safari$", waits: Bool = false, adds words: String?) throws {
        let open = app.map { "'\($0)'" } ?? "true"
        let wait = waits ? "while [ ! -f '\(path("release"))' ]; do sleep 0.02; done\n" : ""
        let add = words.map { "'\(client.path)' context add \($0) 2>> '\(path("errors"))'; echo $? >> '\(path("done"))'" } ?? "echo 0 >> '\(path("done"))'"
        try script(name, toml: "title = '\(name)'\nuses = ['context']\n\n[on]\n\"panel.open\" = \(open)", """
        case "$1" in
          show) echo show >> '\(path("\(name)-log"))'; \(wait)\(add) ;;
        esac
        """)
    }

    func taker(_ name: String = "keep", takes kinds: String) throws {
        try script(name, toml: "title = '\(name)'\n\n[on]\ndrop = [\(kinds)]", """
        case "$1" in
          show) printf 'text=x\\ntitle=\(name)\\n' ;;
          drop) grep '^input\\.' >> '\(path("\(name)-drops"))' ;;
        esac
        """)
    }

    func witness() throws {
        try script("witness", toml: "title = 'Witness'\n\n[on]\n\"panel.open\" = true", """
        case "$1" in
          show) echo show >> '\(path("witness-log"))'; printf 'text=x\\ntitle=Witness\\n' ;;
        esac
        """)
    }

    func open() async {
        await model.reload()
        model.isShown = true
        model.panelWillShow()
    }

    var chips: [ContextChip] {
        model.context.chips
    }

}
