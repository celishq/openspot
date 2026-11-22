import Foundation

public enum SpotStarter: String, CaseIterable, Sendable {
    case button
    case list
    case number
    case form

    var symbol: String {
        switch self {
        case .button: "hand.tap"
        case .list: "list.bullet"
        case .number: "clock"
        case .form: "square.and.pencil"
        }
    }

    public func write(name: String, in folder: URL) throws -> URL {
        try Self.write(name: name, in: folder, manifest: manifest(title:), text: text)
    }

    static func write(name: String, in folder: URL, manifest: (String) -> ConfigDocument, text: String) throws -> URL {
        let slug = slug(of: name)
        guard !slug.isEmpty else { throw SpotError.fault("Use letters or digits in the name.") }
        guard !isTaken(slug, in: folder) else { throw SpotError.fault("A spot called \(slug) already exists. Choose another name.") }
        let place = folder.appendingPathComponent("\(slug).\(SpotPackage.fileExtension)", isDirectory: true)
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        let file = place.appendingPathComponent("\(slug).sh")
        let title = name.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        try manifest(title).text.write(to: place.appendingPathComponent(Manifest.fileName), atomically: true, encoding: .utf8)
        try text.write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        return file
    }

    private static func isTaken(_ slug: String, in folder: URL) -> Bool {
        ["", ".\(SpotPackage.fileExtension)", ".sh"].contains { FileManager.default.fileExists(atPath: folder.appendingPathComponent(slug + $0).path) }
    }

    static func slug(of name: String) -> String {
        let words = name.lowercased().unicodeScalars.split { !("a"..."z").contains($0) && !("0"..."9").contains($0) }
        return words.map { String(String.UnicodeScalarView($0)) }.joined(separator: "-")
    }

    private func manifest(title: String) -> ConfigDocument {
        var manifest = ConfigDocument()
        manifest.set("title", to: .string(title))
        manifest.set("icon", to: .string(symbol))
        switch self {
        case .button:
            manifest.set("detail", to: .string("Press to run it"))
            manifest.sections.append(ConfigDocument.Table("commands.run", [("title", .string(title))]))
        case .list, .form: break
        case .number: manifest.set("on", to: .strings(["panel.open"]))
        }
        return manifest
    }

    private var text: String {
        switch self {
        case .button:
            """
            #!/bin/sh
            openspot toast 'It works. Change this file to make it do more.'

            """
        case .list:
            """
            #!/bin/sh
            . "$OPENSPOT_SH"
            case "$1" in
              show)
                printf 'item=first\\ntitle=First item\\ndetail=Press Enter to pick it\\nnote=Hello\\n\\n'
                printf 'item=second\\ntitle=Second item\\ndetail=Press Enter to pick it\\nnote=Hello again\\n'
                ;;
              open)
                openspot toast "You picked the item that says: $(value item.note)"
                ;;
            esac

            """
        case .number:
            """
            #!/bin/sh
            printf 'frame=\\ntitle=%s\\ndetail=Reads each time the panel opens\\n' "$(date +%H:%M)"

            """
        case .form:
            """
            #!/bin/sh
            . "$OPENSPOT_SH"
            case "$1" in
              show)
                printf 'frame=\\nclass=gap-part\\n\\n'
                printf 'field=note\\ntype=multiline\\ntitle=Note\\nplaceholder=Write a note\\n\\n'
                printf 'button=save\\ntitle=Save\\nshortcut=cmd+return\\nclass=bg-accent\\n'
                ;;
              save)
                printf '%s\\n' "$(value input.note)" >> "$OPENSPOT_DATA/notes.txt"
                openspot toast Saved
                ;;
            esac

            """
        }
    }
}
