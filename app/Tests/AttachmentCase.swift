import XCTest
@testable import OpenspotCore

@MainActor
class AttachmentCase: PanelCase {
    var client: URL!

    override func setUp() async throws {
        try await super.setUp()
        client = folder.appendingPathComponent("A.app/Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: client)
        takeCalls()
        host.frontApp = FrontApp(bundleID: "com.apple.Safari")
    }

    func path(_ name: String) -> String {
        folder.appendingPathComponent(name).path
    }

    func log(_ name: String) -> [String] {
        ((try? String(contentsOfFile: path(name), encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    func source(_ name: String = "tab", waits: Bool = false, adds words: String?) throws {
        let wait = waits ? "while [ ! -f '\(path("release"))' ]; do sleep 0.02; done\n" : ""
        let add = words.map { "'\(client.path)' attachment add \($0) 2>> '\(path("errors"))'; echo $? >> '\(path("done"))'" } ?? "echo 0 >> '\(path("done"))'"
        try script(name, toml: "title = '\(name)'\nuses = ['attachment']\n\n[on]\n\"panel.open\" = true", """
        case "$1" in
          show) echo show >> '\(path("\(name)-log"))'; \(wait)\(add) ;;
        esac
        """)
    }

    var cli: String {
        "'\(client.path)'"
    }

    func pickSource(_ name: String = "tab", app: String = "^com\\.apple\\.Safari$", waits: Bool = false, runs body: String) throws {
        let wait = waits ? "while [ ! -f '\(path("release"))' ]; do sleep 0.02; done\n" : ""
        try script(name, toml: "title = '\(name)'\nuses = ['attachment', 'read']\n\n[on]\n\"attachment.pick\" = '\(app)'", """
        case "$1" in
          attachment.pick) echo pick >> '\(path("\(name)-log"))'; \(wait)\(body); echo $? >> '\(path("done"))' ;;
        esac
        """)
    }

    func unblock() {
        FileManager.default.createFile(atPath: path("release"), contents: Data())
    }

    func taker(_ name: String = "keep", detail: String? = nil, takes kinds: String) throws {
        let words = kinds.split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " '")) }
        let values = words.filter { $0 == "url" || $0 == "text" }
        let files = words.filter { !values.contains($0) }.map { "'\($0)'" }
        let actions = values.map { "[actions.\($0)]\ntitle = '\(name)'\noffers = ['attachments']\ninputs.\($0) = { type = '\($0)', required = true }\ninputs.title = 'text'\n" }
        let line = detail.map { "detail = '\($0)'\n" } ?? ""
        let drop = files.isEmpty ? "" : "\n[on]\ndrop = [\(files.joined(separator: ", "))]"
        try script(name, toml: "title = '\(name)'\n\(line)\n\(actions.joined(separator: "\n"))\(drop)", """
        case "$1" in
          show) printf 'text=x\\ntitle=\(name)\\n' ;;
          drop|url|text) grep '^input\\.' >> '\(path("\(name)-drops"))' ;;
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

    var chips: [AttachmentChip] {
        model.attachments.chips
    }

}
