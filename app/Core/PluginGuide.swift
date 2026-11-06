import Foundation

/// The Plugins spot, which ships with the app. It answers the calls a list script answers, in Swift.
public struct PluginGuide: Equatable, Sendable {
    public let folder: URL
    public let guide: URL
    public let app: String

    public init(folder: URL, guide: URL, app: String) {
        self.folder = folder
        self.guide = guide
        self.app = app
    }

    /// Answers one call with the text a script would print.
    public func answer(_ arguments: [String], input: String?, timeout: TimeInterval) async throws -> String {
        switch arguments.first {
        case nil:
            return Self.rows
        case "form":
            return Self.form
        case "new":
            try await makePlugin(named: TextBlock.blocks(in: input ?? "").first?.value("name") ?? "", timeout: timeout)
            return ""
        case "open":
            try await open(arguments.dropFirst().first ?? "", timeout: timeout)
            return ""
        default:
            throw PluginError.failed(1, "Plugins cannot do that.")
        }
    }

    /// The words that ask an AI to build a plugin.
    public var prompt: String {
        """
        Build an Openspot plugin that does this: <describe what you want>

        Read the guide first: \(guide.path)
        Put the plugin in: \(folder.path)
        To write a sheet of parts, read the language first: "\(app)" catalog
        To see a sheet, run: "\(app)" check --sheet < sheet.txt, and "\(app)" render sheet.png < sheet.txt
        When it is ready, run this and fix each fault it reports: "\(app)" check "\(folder.path)"
        Tell me what the plugin runs on my computer.

        """
    }

    private static let rows = """
    action=new
    title=New plugin
    key=cmd+n
    scope=command
    form=true

    row=Copy prompt for AI
    detail=Have an AI build a plugin for you
    run=prompt
    symbol=sparkles

    row=Try a sheet
    detail=Build a layout and see it at once
    run=sandbox
    symbol=square.grid.2x2

    row=Read the guide
    detail=How plugins and widgets work
    run=guide
    symbol=book

    row=Open plugins folder
    detail=Add a script here to install a plugin
    run=folder
    symbol=folder
    """

    private static let form = """
    title=New plugin

    field=name
    label=Name
    required=true
    placeholder=Weather
    """

    private func open(_ row: String, timeout: TimeInterval) async throws {
        switch row {
        case "prompt":
            try await tool(["LC_ALL=en_US.UTF-8", "pbcopy"], input: prompt, timeout: timeout)
        case "sandbox":
            let bundle = URL(fileURLWithPath: app).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            try await tool(["open", "-n", bundle.path, "--args", "sandbox"], timeout: timeout)
        case "guide":
            try await tool(["open", guide.path], timeout: timeout)
        case "folder":
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try await tool(["open", folder.path], timeout: timeout)
        default:
            throw PluginError.failed(1, "Plugins has no such row.")
        }
    }

    /// Writes a script that the person can edit, and shows it in Finder.
    private func makePlugin(named name: String, timeout: TimeInterval) async throws {
        let words = name.lowercased().unicodeScalars.split { !("a"..."z").contains($0) && !("0"..."9").contains($0) }
        let slug = words.map { String(String.UnicodeScalarView($0)) }.joined(separator: "-")
        guard !slug.isEmpty else { throw PluginError.failed(1, "Use letters or digits in the name.") }
        let file = folder.appendingPathComponent("\(slug).sh")
        let taken = [file, folder.appendingPathComponent(slug)].contains { FileManager.default.fileExists(atPath: $0.path) }
        guard !taken else { throw PluginError.failed(1, "A plugin called \(slug) already exists.") }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let script = """
        #!/bin/sh
        # name=\(name)
        # symbol=star
        # subtitle=Edit \(slug).sh
        open -R "$0"

        """
        try script.write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        try await tool(["open", "-R", file.path], timeout: timeout)
    }

    private func tool(_ arguments: [String], input: String? = nil, timeout: TimeInterval) async throws {
        _ = try await PluginRun(url: URL(fileURLWithPath: "/usr/bin/env"), arguments: arguments, timeout: timeout, input: input).output()
    }
}
