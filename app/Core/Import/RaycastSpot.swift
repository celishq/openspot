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
        script.mode == .fullOutput
    }

    var manifest: ConfigDocument {
        var manifest = ConfigDocument()
        manifest.set("title", to: .string(Self.value(script.title)))
        manifest.set("icon", to: .string(Self.value(icon)))
        if let description = script.description { manifest.set("detail", to: .string(Self.value(description))) }
        if let package = script.package { manifest.set("keywords", to: .strings([Self.value(package)])) }
        if script.mode == .inline {
            manifest.sections.append(ConfigDocument.Table("on", [("\"panel.open\"", .boolean(true)), ("every", script.refreshSeconds.map(ConfigDocument.Value.integer))]))
        } else if hasSheet {
            manifest.sections.append(ConfigDocument.Table("on", [("\"sheet.open\"", .boolean(true))]))
        } else {
            var run: [(String, ConfigDocument.Value?)] = [("title", .string(Self.value(script.title)))]
            if script.confirms { run.append(("confirm", .string("Press again to run \(Self.value(script.title))"))) }
            for (index, argument) in script.arguments.enumerated() {
                run.append(("inputs.arg\(index + 1)", Self.input(argument, number: index + 1)))
            }
            manifest.sections.append(ConfigDocument.Table("actions.run", run))
        }
        return manifest
    }

    static func input(_ argument: RaycastArgument, number: Int) -> ConfigDocument.Value {
        var input: [String: ConfigDocument.Value] = [
            "type": .string(argument.isChoice ? "choice" : "text"),
            "required": .boolean(!argument.isOptional),
            "description": .string(value(RaycastBody.label(number, argument)))
        ]
        if argument.isChoice { input["options"] = .strings(argument.options.map { value($0.value) }) }
        return .table(input)
    }

    public var text: String {
        let place = script.directory.map { ($0 as NSString).expandingTildeInPath } ?? source.deletingLastPathComponent().path
        return """
        #!/bin/sh
        . "$OPENSPOT_SH"
        script="$(dirname "$0")"/\(Self.quoted(copy))
        place=\(Self.quoted(place))
        \(RaycastBody.common)
        \(body)
        """
    }

    var body: String {
        switch script.mode {
        case .inline: RaycastBody.inline
        case .fullOutput: RaycastBody.sheet(arguments: script.arguments, title: script.title, confirms: script.confirms)
        default: RaycastBody.action(arguments: script.arguments)
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
        try manifest.text.write(to: staging.appendingPathComponent(Manifest.fileName), atomically: true, encoding: .utf8)
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
