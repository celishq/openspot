import Foundation

public struct RaycastSpot: Sendable {
    public let script: RaycastScript
    public let source: URL
    public let name: String
    public let icon: String
    let iconCopy: URL?
    let helpers: [URL]

    static let folder = "raycast"
    public static let defaultIcon = "terminal"
    static let iconFile = "icon"

    public init(script: RaycastScript, source: URL, name: String, icon: String = RaycastSpot.defaultIcon, iconCopy: URL? = nil, helpers: [URL] = []) {
        self.script = script
        self.source = source
        self.name = name
        self.icon = icon
        self.iconCopy = iconCopy
        self.helpers = helpers.filter { !Self.isNote($0.lastPathComponent) }
    }

    static func isNote(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasPrefix("readme") || lower.hasPrefix("license") || lower.hasSuffix(".md")
    }

    var copy: String {
        "\(Self.folder)/\(source.lastPathComponent)"
    }

    var hasSheet: Bool {
        !script.arguments.isEmpty || script.mode == .fullOutput
    }

    var header: [String] {
        var lines = ["title=\(Self.value(script.title))"]
        lines.append("icon=\(Self.value(icon))")
        if let description = script.description { lines.append("detail=\(Self.value(description))") }
        if let package = script.package { lines.append("keywords=\(Self.value(package))") }
        if let first = script.arguments.first, !first.placeholder.isEmpty { lines.append("placeholder=\(Self.value(first.placeholder))") }
        if script.mode == .inline, let seconds = script.refreshSeconds {
            lines += ["on=panel.open", "on=clock.\(seconds)", "offers=card", "offers=menubar"]
        } else if hasSheet {
            lines.append("on=sheet.open")
        } else if script.confirms {
            lines += ["", "button=run", "title=\(Self.value(script.title))", "confirm=Press again to run \(Self.value(script.title))"]
        }
        return lines
    }

    public var text: String {
        let header = header.map { $0.isEmpty ? "#" : "# \($0)" }.joined(separator: "\n")
        let place = script.directory.map { ($0 as NSString).expandingTildeInPath } ?? source.deletingLastPathComponent().path
        return """
        #!/bin/sh
        \(header)
        . "$OPENSPOT_SH"
        script="$(dirname "$0")"/\(Self.quoted(copy))
        place=\(Self.quoted(place))
        \(RaycastBody.common)
        \(body)
        """
    }

    var body: String {
        switch (script.mode, hasSheet) {
        case (.inline, _): RaycastBody.inline
        case (_, false): RaycastBody.toast
        case (_, true): RaycastBody.sheet(arguments: script.arguments, title: script.title, mode: script.mode, confirms: script.confirms)
        }
    }

    public var readme: String {
        "# \(script.title)\n\n" + (script.description.map { "\($0)\n\n" } ?? "") + "Imported from the Raycast script command `\(source.lastPathComponent)`.\n"
    }

    public func write(in spots: URL) throws -> URL {
        let manager = FileManager.default
        let target = spots.appendingPathComponent("\(name).spot", isDirectory: true)
        let staging = spots.appendingPathComponent(".\(name).import-\(UUID().uuidString.prefix(8))", isDirectory: true)
        defer { try? manager.removeItem(at: staging) }
        try manager.createDirectory(at: staging.appendingPathComponent(Self.folder), withIntermediateDirectories: true)
        let wrapper = staging.appendingPathComponent("\(name).sh")
        try text.write(to: wrapper, atomically: true, encoding: .utf8)
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapper.path)
        let original = staging.appendingPathComponent(copy)
        try manager.copyItem(at: source.resolvingSymlinksInPath(), to: original)
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: original.path)
        for helper in helpers {
            try manager.copyItem(at: helper.resolvingSymlinksInPath(), to: staging.appendingPathComponent(Self.folder).appendingPathComponent(helper.lastPathComponent))
        }
        try readme.write(to: staging.appendingPathComponent("readme.md"), atomically: true, encoding: .utf8)
        if let iconCopy {
            try manager.copyItem(at: iconCopy, to: staging.appendingPathComponent(icon))
        }
        try manager.moveItem(at: staging, to: target)
        return target
    }

    static func value(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: " ")
    }

    static func quoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
