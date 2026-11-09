import Foundation

/// A working spot to start from, which a person or an agent then changes: a button, a list, a value that reads when the
/// panel opens, or a form.
public enum SpotStarter: String, CaseIterable, Sendable {
    case button
    case list
    case number
    case form

    /// The words of each starter in a list for a person.
    public var title: String {
        switch self {
        case .button: "Button"
        case .list: "List"
        case .number: "Live value"
        case .form: "Form"
        }
    }

    /// What the starter makes, in words for a person.
    public var detail: String {
        switch self {
        case .button: "Runs a command when you press it"
        case .list: "Shows rows that you search and pick"
        case .number: "Shows a value each time the panel opens"
        case .form: "Asks for text and saves it"
        }
    }

    public var symbol: String {
        switch self {
        case .button: "hand.tap"
        case .list: "list.bullet"
        case .number: "clock"
        case .form: "square.and.pencil"
        }
    }

    /// Writes this starter as a new script in the folder, and returns its file. The file takes the words of the name in
    /// lowercase with dashes, and the spot takes the name as its title. A name that another spot has is refused.
    public func write(name: String, in folder: URL) throws -> URL {
        let slug = Self.slug(of: name)
        guard !slug.isEmpty else { throw PluginError.fault("Use letters or digits in the name.") }
        let taken = PluginFolder(url: folder).file(of: slug) != nil || FileManager.default.fileExists(atPath: folder.appendingPathComponent(slug).path)
        guard !taken else { throw PluginError.fault("A spot called \(slug) already exists. Choose another name.") }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("\(slug).sh")
        let title = name.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        try text(title: title).write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        return file
    }

    /// The words of a name in lowercase, joined by dashes, with only Latin letters and digits.
    static func slug(of name: String) -> String {
        let words = name.lowercased().unicodeScalars.split { !("a"..."z").contains($0) && !("0"..."9").contains($0) }
        return words.map { String(String.UnicodeScalarView($0)) }.joined(separator: "-")
    }

    private func text(title: String) -> String {
        switch self {
        case .button:
            """
            #!/bin/sh
            # title=\(title)
            # icon=\(symbol)
            # detail=Press to run it
            echo 'toast=It works. Change this file to make it do more.'

            """
        case .list:
            """
            #!/bin/sh
            # title=\(title)
            # icon=\(symbol)
            # read=sheet
            case "$1" in
              read)
                printf 'row=first\\ntitle=First row\\ndetail=Press Enter to pick it\\n\\n'
                printf 'row=second\\ntitle=Second row\\ndetail=Press Enter to pick it\\n'
                ;;
              open)
                printf 'toast=You picked %s\\n' "$2"
                ;;
            esac

            """
        case .number:
            """
            #!/bin/sh
            # title=\(title)
            # icon=\(symbol)
            # read=panel
            printf 'title=%s\\ndetail=Reads each time the panel opens\\n' "$(date +%H:%M)"

            """
        case .form:
            """
            #!/bin/sh
            # title=\(title)
            # icon=\(symbol)
            # read=sheet
            . "$OPENSPOT_SH"
            case "$1" in
              read)
                printf 'grid=note\\ngrid=save\\n\\n'
                printf 'field=note\\ntitle=Note\\nplaceholder=Write a note\\n\\n'
                printf 'button=save\\ntitle=Save\\nshortcut=cmd+return\\nlook=strong\\nclose=true\\n'
                ;;
              save)
                printf '%s\\n' "$(value note)" >> "$OPENSPOT_DATA/notes.txt"
                echo 'toast=Saved'
                ;;
            esac

            """
        }
    }
}
