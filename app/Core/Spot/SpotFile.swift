import Foundation

public struct SpotFile: Equatable, Sendable {
    public static let inlineExtension = "js"
    private static let search = "search"

    public let id: String
    public let spots: [Spot]

    public init(id: String, spots: [Spot]) {
        self.id = id
        self.spots = spots
    }

    public init?(file url: URL, id: String, manifest: Manifest? = nil, isApp: Bool = false) throws {
        if SwiftProgram.isProgram(url) { return nil }
        let manifest = manifest ?? Manifest(beside: url)
        guard Self.runs(url, manifest: manifest) else { return nil }
        try self.init(script: url, manifest: manifest.script(url), id: id, isApp: isApp)
    }

    public init(script url: URL, manifest: Manifest, id: String, isApp: Bool = false) throws {
        let name = manifest.title ?? Self.name(of: url)
        if let key = manifest.unknownKey(isApp: isApp) {
            throw SpotError.fault("\(name) has an unknown key in its \(Manifest.fileName): \(key)")
        }
        let tables = manifest.commands.map { ($0.section, $0.unknownKey) } + manifest.settings.map { ($0.section, $0.unknownKey) }
        if let (section, key) = tables.first(where: { $0.1 != nil }) {
            throw SpotError.fault("\(name) has an unknown key in \(section): \(key ?? "")")
        }
        let icon = Icon(text: manifest.icon).map { Self.placed($0, beside: url) }
        if let triggers = manifest.triggers {
            let old = [("on", !manifest.on.isEmpty), ("offers", !manifest.offers.isEmpty), ("drop", !manifest.drop.isEmpty), ("placeholder", manifest.placeholder != nil)]
            if let (key, _) = old.first(where: \.1) {
                throw SpotError.fault("\(name) has both \(key) and [on] in its \(Manifest.fileName). Move \(key) into [on]")
            }
            if let key = triggers.bindings.first(where: { key in !manifest.bindings.contains { $0.name == Manifest.Triggers.binding(of: key) } }) {
                let binding = Manifest.Triggers.binding(of: key)
                throw SpotError.fault("\(name) has [on] \(key), which names no binding \(binding). Add it to [bindings], such as \(binding) = { spot = \"<id>\" }")
            }
            if let action = manifest.actions.first(where: { triggers.handlers.contains($0.id) }) {
                throw SpotError.fault("\(name) has \(action.section), which takes the name of a handler that its [on] calls. Give the action another ID")
            }
        }
        let parsed = try manifest.triggers.map(\.showEvents) ?? ShowEvents(on: manifest.on, of: name)
        var on = parsed?.moments.isEmpty == false ? parsed : nil
        if let word = manifest.emits.first(where: { !SpotEvent.isName($0) }) {
            throw SpotError.fault("\(name) has an unknown event in its emits: \(word). Write a word with a dot, such as emits = [\"music.track\"]")
        }
        let uses = try SpotUse.set(manifest.uses, of: name)
        let isInline = url.pathExtension == Self.inlineExtension && !FileManager.default.isExecutableFile(atPath: url.path)
        if manifest.stay != nil, manifest.mode != nil {
            throw SpotError.fault("\(name) has both stay and mode in its \(Manifest.fileName). Keep stay = true, and remove mode")
        }
        let modeName = manifest.mode ?? (manifest.stay == true ? SpotMode.stay : SpotMode.once).rawValue
        guard let named = SpotMode(rawValue: modeName), named != .inline else {
            throw SpotError.fault("\(name) has an unknown mode: \(modeName). Use once or stay")
        }
        if isInline, named != .once {
            throw SpotError.fault("\(name) is a .js file, which runs inline, so it takes no mode = \"\(modeName)\"")
        }
        let mode = isInline ? SpotMode.inline : named
        let isGlobal = try Self.isGlobal(manifest.offers, of: name) || manifest.triggers?.lists == true
        let order = manifest.answers
        guard order == nil || order == "last" || order == "card" else {
            throw SpotError.fault("\(name) has an unknown answers: \(order ?? ""). Use answers = \"last\" or answers = \"card\"")
        }
        guard order == nil || parsed?.answers != nil else {
            throw SpotError.fault("\(name) has answers = \"\(order ?? "")\", which needs search.text in its on, such as on = [\"search.text ^[0-9]\"], or search in its [on], such as search = \"^[0-9]\"")
        }
        let answers = order == "last" ? parsed?.answers?.last() : order == "card" ? parsed?.answers?.card() : parsed?.answers
        let answersOnly = answers != nil && on == nil
        if let setting = manifest.settings.first(where: { ReservedSetting.isReserved($0.id) }) {
            throw SpotError.fault("\(name) has \(setting.section), a key that Openspot keeps for the person. Give the setting another name.")
        }
        if let setting = manifest.settings.first(where: { $0.valueType == nil && $0.type.map { $0 != Manifest.Setting.secret } == true }) {
            throw SpotError.fault("\(name) has an unknown type in \(setting.section): `\(setting.type ?? "")`. Use `type = \"secret\"`, or no type.")
        }
        let offeredActions = try OfferedAction.read(manifest.commands, owner: id, of: name, isInline: mode == .inline)
        let offeredIDs = Set(offeredActions.map(\.action.id))
        if let action = manifest.actions.first(where: { action in manifest.commands.contains { $0.id == action.id } }) {
            throw SpotError.fault("\(name) has both [commands.\(action.id)] and \(action.section). Give the action another ID")
        }
        let offers = manifest.commands.filter { !offeredIDs.contains($0.id) } + manifest.actions.compactMap(\.command)
        if let command = offers.first(where: { $0.title.isEmpty || $0.id == "show" || $0.id.contains(where: \.isWhitespace) }) {
            throw SpotError.fault("\(name) cannot read \(command.section). Give it an ID with no space and a title, such as [commands.left] with title = \"Left side\"")
        }
        if manifest.views.contains(where: { URL(fileURLWithPath: $0).pathExtension != SwiftProgram.sourceExtension }) {
            throw SpotError.fault("\(name) needs a Swift file for each of its views, such as views = [\"liquid.swift\"]")
        }
        let sources = manifest.source
        if !sources.isEmpty, url.pathExtension != SwiftProgram.sourceExtension {
            throw SpotError.fault("\(name) has source = [\"\(sources[0])\"], which only a Swift spot takes. Remove it, or write the spot in a .swift file")
        }
        if let source = sources.first(where: { !SpotPackage.isSafe(entry: $0) || $0.isEmpty }) {
            throw SpotError.fault("\(name) has source = [\"\(source)\"], which is outside its folder. Name a Swift file or a folder beside the spot, such as source = [\"model\"]")
        }
        if let source = sources.first(where: { $0.split(separator: "/", omittingEmptySubsequences: false).contains { $0.isEmpty || $0 == "." } }) {
            throw SpotError.fault("\(name) has `source = [\"\(source)\"]`, which is not a plain path. Write it with no `.`, no `..` and no `/` at its start or end, such as `source = [\"model\"]`.")
        }
        let edits = manifest.edits.flatMap(SpotEdits.init(rawValue:))
        guard manifest.edits == nil || edits != nil else { throw SpotError.fault("\(name) has an unknown edits: \(manifest.edits ?? ""). Use edits = \"spots\".") }
        let starts = manifest.starts.flatMap(SpotStart.init(rawValue:))
        guard manifest.starts == nil || starts != nil else {
            throw SpotError.fault("\(name) has an unknown starts: \(manifest.starts ?? ""). Use starts = \"first-launch\".")
        }
        if isGlobal, on?.has(.panel) != true, on?.has(.sheet) != true, on?.seconds == nil {
            on = on?.adding(.sheet) ?? .sheet
        }
        let isFound = !answersOnly && (offeredActions.isEmpty || isGlobal)
        var command = Spot(
            id: id,
            name: name,
            url: url,
            kind: .list,
            icon: icon,
            subtitle: manifest.detail,
            on: on,
            isFound: isFound,
            answers: answers,
            mode: mode,
            drop: manifest.triggers?.drop ?? manifest.drop,
            isGlobal: isGlobal,
            dataName: SpotID(id).name,
            isOnGrid: isFound && offers.isEmpty && on?.seconds == nil,
            offers: offers,
            offeredActions: offeredActions,
            settings: manifest.settings.filter { Manifest.Setting.isKey($0.id) },
            views: Dictionary(manifest.views.map { (URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent, Self.path($0, beside: url)) }) { first, _ in first },
            viewDates: Dictionary(manifest.views.map { Self.path($0, beside: url) }.compactMap { view in Self.viewDate(of: view, script: url).map { (view, $0) } }) { first, _ in first },
            sources: sources,
            emits: manifest.emits,
            pages: manifest.pages,
            uses: uses,
            keywords: manifest.keywords,
            placeholder: manifest.placeholder,
            sample: Self.sample(beside: url),
            edits: edits,
            starts: starts
        )
        command.typedActions = manifest.actions
        command.triggers = manifest.triggers
        command.bindings = manifest.bindings
        command.events = manifest.events
        command.commandWords = manifest.triggers?.commands ?? []
        self.init(id: id, spots: [command])
    }

    static func runs(_ url: URL, manifest: Manifest) -> Bool {
        if SpotSample.isScript(url) || !manifest.describes(url.lastPathComponent) { return false }
        if FileManager.default.isExecutableFile(atPath: url.path) { return true }
        return url.pathExtension == inlineExtension && manifest.isWritten
    }

    private static func isGlobal(_ offers: [String], of name: String) throws -> Bool {
        for word in offers.map({ $0.trimmingCharacters(in: .whitespaces) }) where word != search {
            if word == OfferedAction.place {
                throw SpotError.fault("\(name) offers actions at its top level. Write offers = [\"actions\"] on a command, such as in [commands.change]")
            }
            throw SpotError.fault("\(name) offers an unknown place: \(word). Use offers = [\"search\"]")
        }
        return !offers.isEmpty
    }

    private static func sample(beside url: URL) -> URL? {
        let sample = SpotSample.script(beside: url)
        return SpotSample.isScript(sample) && FileManager.default.isExecutableFile(atPath: sample.path) ? sample : nil
    }

    private static func viewDate(of view: String, script: URL) -> Date? {
        let folder = script.deletingLastPathComponent().path
        let isLinked = (try? FileManager.default.destinationOfSymbolicLink(atPath: folder)) != nil
        guard (view as NSString).deletingLastPathComponent == folder, !isLinked else { return nil }
        return try? FileManager.default.attributesOfItem(atPath: view)[.modificationDate] as? Date
    }

    private static func placed(_ icon: Icon, beside url: URL) -> Icon {
        switch icon {
        case .file(let path): .file(Self.path(path, beside: url))
        case .image(let path): .image(Self.path(path, beside: url))
        case .symbol, .glyph: icon
        }
    }

    private static func path(_ text: String, beside url: URL) -> String {
        text.hasPrefix("/") || WebPictures.isWeb(text) ? text : url.deletingLastPathComponent().appendingPathComponent(text).path
    }

    static func name(of url: URL) -> String {
        let words = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}
