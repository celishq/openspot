import Foundation

/// What one file in the plugin folder gives: an executable, or a TOML file of widgets.
public struct SpotFile: Equatable, Sendable {
    public static let widgetExtension = "toml"
    public static let inlineExtension = "js"

    public let id: String
    public let spots: [Spot]

    public init(id: String, spots: [Spot]) {
        self.id = id
        self.spots = spots
    }

    /// Reads a file with no run of it. Returns nil for a file that is neither. Throws a fault that names what is wrong.
    public init?(file url: URL, id: String) throws {
        if SwiftProgram.isProgram(url) { return nil }
        if url.pathExtension == Self.widgetExtension {
            let document = try TomlDocument(text: try String(contentsOf: url, encoding: .utf8))
            self.init(id: id, spots: try (document.arrays["widgets"] ?? []).map { try Self.widget($0, id: id, url: url) })
        } else if Self.runs(url) {
            try self.init(script: url, header: SpotHeader(url: url).block, id: id)
        } else {
            return nil
        }
    }

    /// A script with a clock starts off the grid until the person shows it (F7).
    public init(script url: URL, header: TextBlock, id: String) throws {
        let name = header.value("title") ?? Self.name(of: url)
        let icon = Icon(text: header.value("icon"))
        let symbol = icon?.symbol
        try Self.refuseOldKeys(header, of: name)
        let on = try SpotRead(on: header.values("on"), of: name)
        let read = on?.moments.isEmpty == false ? on : nil
        let emits = SpotRead.words(header.value("emits"))
        if let word = emits.first(where: { !SpotEvent.isName($0) }) {
            throw SpotError.fault("\(name) has an unknown event in its emits: \(word). Write a word with a dot, such as emits=music.track")
        }
        let uses = try SpotUse.set(header.value("uses"), of: name)
        let isInline = url.pathExtension == Self.inlineExtension
        let modeName = header.value("mode") ?? SpotMode.once.rawValue
        guard let named = SpotMode(rawValue: modeName), named != .inline else {
            if modeName == SpotMode.inline.rawValue {
                throw SpotError.fault("\(name) has mode=inline, which Openspot no longer reads. A .js file runs inline, so remove the line")
            }
            throw SpotError.fault("\(name) has an unknown mode: \(modeName). Use once, stay or always")
        }
        if isInline, named != .once {
            throw SpotError.fault("\(name) is a .js file, which runs inline, so it takes no mode=\(modeName)")
        }
        let mode = isInline ? SpotMode.inline : named
        let sizeName = header.value("size") ?? "wide"
        guard let size = SpotSize(name: sizeName) else { throw SpotError.fault("\(name) has an unknown size: \(sizeName)") }
        let places = try Self.places(header.value("offers"), of: name)
        let isGlobal = places.contains("search")
        if isGlobal {
            guard read?.has(.panel) == true || read?.seconds != nil else {
                throw SpotError.fault("\(name) needs on=panel.open or a clock, such as on=clock.60, to join the main search")
            }
        }
        let answers = on?.answers
        let answersOnly = answers != nil && read == nil
        let offers = try header.children.filter { $0.fields.first?.key == "button" }.map { block in
            guard let offer = CommandOffer(block: block) else {
                throw SpotError.fault("\(name) cannot read the button \(block.value("button") ?? ""). Give it an ID with no space and a title, such as button=left with title=Left side")
            }
            return offer
        }
        let view = header.value("view")
        if let view, URL(fileURLWithPath: view).pathExtension != SwiftProgram.sourceExtension {
            throw SpotError.fault("\(name) needs a Swift file for its view, such as view=\(url.deletingPathExtension().lastPathComponent).swift")
        }
        if let view, !id.contains("/") {
            throw SpotError.fault("\(name) has a view, so it needs a folder of its own. Move \(url.lastPathComponent) and \(view) into a folder such as \(id)/")
        }
        let preview = header.value("preview")
        guard preview == nil || preview == "sample" else {
            throw SpotError.fault("\(name) has an unknown preview: \(preview!). Use preview=sample, and print fake data while OPENSPOT_REASON is spot.preview")
        }
        let kind: SpotKind = mode.stays || isGlobal || read?.has(.sheet) == true || read?.seconds != nil ? .list : .launch
        let command = Spot(
            id: id,
            name: name,
            url: url,
            kind: kind,
            size: size,
            symbol: symbol ?? "app",
            subtitle: header.value("detail"),
            read: read,
            isGlobal: isGlobal,
            isFound: !answersOnly,
            answers: answers,
            mode: mode,
            drop: header.value("drop")?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? [],
            offersFloat: kind == .list,
            dataName: id.split(separator: "/").first.map(String.init),
            isOnGrid: offers.isEmpty && read?.seconds == nil && !answersOnly,
            headerSymbol: symbol,
            offers: offers,
            settings: header.children.filter { $0.fields.first?.key == "field" }.compactMap { CommandOffer(setting: $0) },
            file: icon?.file.map { Self.path($0, beside: url) },
            image: icon?.image.map { Self.path($0, beside: url) },
            glyph: icon?.glyph,
            view: view.map { Self.path($0, beside: url) },
            emits: emits,
            uses: uses,
            keywords: header.values("keyword"),
            previewsSample: preview != nil
        )
        self.init(id: id, spots: [command])
    }

    /// Whether a file is a spot that runs: an executable, or a JavaScript file with a header.
    private static func runs(_ url: URL) -> Bool {
        if FileManager.default.isExecutableFile(atPath: url.path) { return true }
        return url.pathExtension == inlineExtension && !SpotHeader(url: url).block.fields.isEmpty
    }

    /// The places that `offers` names. Only `search` is a place, and `rows` and `float` name their fix.
    private static func places(_ text: String?, of name: String) throws -> Set<String> {
        guard let text else { return [] }
        let words = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if words.contains("rows") {
            throw SpotError.fault("\(name) offers rows, which Openspot no longer reads. Use offers=search, and the person hides its card")
        }
        if words.contains("float") {
            throw SpotError.fault("\(name) offers float, which Openspot no longer reads. The person floats any spot with a sheet in Settings, so remove it")
        }
        if let word = words.first(where: { $0 != "search" }) {
            throw SpotError.fault("\(name) offers an unknown place: \(word). Use offers=search")
        }
        return Set(words)
    }

    /// Refuses a header that still has `global`, `float`, `tray`, `data`, `stay` or `shortcut`, and names the new way.
    private static func refuseOldKeys(_ header: TextBlock, of name: String) throws {
        if let read = header.value("read") {
            let events = SpotRead.words(read).compactMap { ["panel": "on=panel.open", "sheet": "on=sheet.open"][$0] }
            let fix = events.isEmpty ? "an event, such as on=sheet.open" : events.joined(separator: " and ")
            throw SpotError.fault("\(name) has read=\(read), which Openspot no longer reads. Write \(fix)")
        }
        if let every = header.value("every") {
            throw SpotError.fault("\(name) has every=\(every), which Openspot no longer reads. Write on=clock.\(every)")
        }
        if let answers = header.value("answers") {
            throw SpotError.fault("\(name) has answers=\(answers), which Openspot no longer reads. Write on=search.text \(answers)")
        }
        if header.value("stay") != nil {
            throw SpotError.fault("\(name) has stay, which Openspot no longer reads. Use mode=stay or mode=always")
        }
        let commands = header.values("command") + header.children.compactMap { $0.value("command") }
        if let command = commands.first {
            throw SpotError.fault("\(name) has command=\(command), which Openspot no longer reads. Write each command as a button block after a blank comment line, such as button=left with title=Left side")
        }
        let settings = header.values("setting") + header.children.compactMap { $0.value("setting") }
        if let setting = settings.first {
            throw SpotError.fault("\(name) has setting=\(setting), which Openspot no longer reads. Write each setting as a field block after a blank comment line, such as field=folder with title=Folder")
        }
        if header.value("settings") != nil {
            throw SpotError.fault("\(name) has settings, which Openspot no longer reads. Write each setting as a field block after a blank comment line, such as field=folder with title=Folder")
        }
        if let global = header.value("global") {
            throw SpotError.fault("\(name) has global=\(global), which Openspot no longer reads. Use offers=search")
        }
        if header.value("float") != nil {
            throw SpotError.fault("\(name) has float, which Openspot no longer reads. The person floats any spot with a sheet in Settings, so remove it")
        }
        if header.value("tray") != nil {
            throw SpotError.fault("\(name) has tray, which Openspot no longer reads. The person puts a spot in the menu bar in Settings")
        }
        if header.value("data") != nil {
            throw SpotError.fault("\(name) has data, which Openspot no longer reads. The scripts of one folder share OPENSPOT_DATA, so move them into one folder")
        }
        try refuseLetter(header.value("shortcut"), of: name)
    }

    /// Refuses a letter that a file names, because the person gives each spot its letter.
    private static func refuseLetter(_ text: String?, of name: String) throws {
        guard text != nil else { return }
        throw SpotError.fault("\(name) has shortcut, which Openspot no longer reads. The person gives each spot its letter in Edit Spots")
    }

    /// A path that the header names: a full path or an https URL stays, and any other starts at the folder of the script.
    private static func path(_ text: String, beside url: URL) -> String {
        text.hasPrefix("/") || WebPictures.isWeb(text) ? text : url.deletingLastPathComponent().appendingPathComponent(text).path
    }

    /// The name a file gives when it has no `name` line: its words with a capital first letter.
    static func name(of url: URL) -> String {
        let words = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }


    private static func widget(_ table: [String: TomlDocument.Value], id: String, url: URL) throws -> Spot {
        func text(_ key: String) -> String? {
            if case .string(let value)? = table[key] { return value }
            return nil
        }
        guard let name = text("title") else { throw SpotError.fault("a widget needs a title") }
        try refuseLetter(text("shortcut"), of: name)
        if case .strings(let drawing)? = table["grid"] {
            return try drawn(drawing, table, name: name, id: id, url: url)
        }
        throw SpotError.fault("\(name) needs a grid that names its metrics, such as grid = [\"cpu cpu memory\"]")
    }

    /// A widget with a drawing of its own, whose words name its metrics.
    private static func drawn(_ drawing: [String], _ table: [String: TomlDocument.Value], name: String, id: String, url: URL) throws -> Spot {
        func text(_ key: String) -> String? {
            if case .string(let value)? = table[key] { return value }
            return nil
        }
        if let fault = WidgetLayout.faults(in: drawing).first { throw SpotError.fault("\(name): \(fault)") }
        var size: SpotSize?
        if let sizeName = text("size") {
            guard let asked = SpotSize(name: sizeName) else { throw SpotError.fault("\(name) has an unknown size: \(sizeName)") }
            size = asked
        }
        if table["places"] != nil {
            throw SpotError.fault("\(name) has places, which Openspot no longer reads. Its grid names each metric, such as grid = [\"cpu cpu memory\"]")
        }
        let layout = WidgetLayout(drawing: drawing, size: size)
        return Spot(
            id: "\(id)/\(name)",
            name: name,
            url: url,
            kind: .widget,
            size: layout.size,
            subtitle: text("detail"),
            layout: layout,
            places: layout.names.map { tool($0, beside: url, id: id) },
            opens: text("opens").map { tool($0, beside: url, id: id) }
        )
    }

    /// The ID of a tool that a widget names: a script of the widget's own folder by its file name first, else the name as an
    /// ID (F10).
    private static func tool(_ name: String, beside url: URL, id: String) -> String {
        guard !name.contains("/"), let folder = id.split(separator: "/").first, id.contains("/") else { return name }
        let files = (try? FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)) ?? []
        let isOwn = files.contains { $0.deletingPathExtension().lastPathComponent == name && runs($0) }
        return isOwn ? "\(folder)/\(name)" : name
    }
}
