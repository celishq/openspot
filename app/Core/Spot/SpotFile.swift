import Foundation

public struct SpotFile: Equatable, Sendable {
    public static let inlineExtension = "js"

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
        if manifest.hasScripts, !isApp {
            throw SpotError.fault("\(manifest.title ?? Self.name(of: url)) has an unknown key in its \(Manifest.fileName): \(Manifest.scriptsTable)")
        }
        try self.init(script: url, manifest: manifest.script(url), id: id, isApp: isApp)
    }

    public init(script url: URL, manifest: Manifest, id: String, isApp: Bool = false) throws {
        let name = manifest.title ?? Self.name(of: url)
        if let key = manifest.unknownKey(isApp: isApp) {
            throw SpotError.fault("\(name) has an unknown key in its \(Manifest.fileName): \(key)")
        }
        if let action = manifest.actions.first(where: { !isApp && $0.appKey == "offers" }) {
            throw SpotError.fault("\(name) has offers = [\"\(action.offers.first ?? "")\"] in \(action.section). A spot offers only offers = [\"\(Manifest.Action.attachments)\"]")
        }
        if let action = manifest.actions.first(where: { !isApp && $0.appKey != nil }) {
            throw SpotError.fault("\(name) has an unknown key in \(action.section): \(action.appKey ?? "")")
        }
        let icon = Icon(text: manifest.icon).map { Self.placed($0, beside: url) }
        try manifest.triggers.check(manifest, name: name)
        let uses = try SpotUse.set(manifest.uses, of: name)
        if uses.contains(.attachment), manifest.triggers.filters[EventName.panelOpen] != nil {
            throw SpotError.fault("\(name) uses attachment, so its [on] \"panel.open\" takes only true. Tie it to an app with \"attachment.pick\" = \"<regex>\"")
        }
        let isInline = url.pathExtension == Self.inlineExtension && !FileManager.default.isExecutableFile(atPath: url.path)
        if isInline, manifest.stay == true {
            throw SpotError.fault("\(name) is a .js file, which runs inline, so it takes no stay = true")
        }
        let mode = isInline ? SpotMode.inline : manifest.stay == true ? SpotMode.stay : SpotMode.once
        let order = manifest.answers
        guard order == nil || order == "last" || order == "card" else {
            throw SpotError.fault("\(name) has an unknown answers: \(order ?? ""). Use answers = \"last\" or answers = \"card\"")
        }
        guard order == nil || manifest.triggers.search != nil else {
            throw SpotError.fault("\(name) has answers = \"\(order ?? "")\", which needs search in its [on], such as search = \"^[0-9]\"")
        }
        let triggers = manifest.triggers.answering(order)
        if let setting = manifest.settings.first(where: { ReservedSetting.isReserved($0.id) }) {
            throw SpotError.fault("\(name) has \(setting.section), a key that Openspot keeps for the person. Give the setting another name.")
        }
        let titled = manifest.actions.filter { $0.title != nil && !$0.isChipOnly }
        let offeredActions = try OfferedAction.read(titled, owner: id, of: name, isInline: mode == .inline)
        let offeredIDs = Set(offeredActions.map(\.action.id))
        let commands = titled.filter { !offeredIDs.contains($0.id) }
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
        guard manifest.edits == nil || edits != nil else { throw SpotError.fault("\(name) has an unknown edits: \(manifest.edits ?? ""). Use edits = \"spots\" or edits = \"attachments\".") }
        let starts = manifest.starts.flatMap(SpotStart.init(rawValue:))
        guard manifest.starts == nil || starts != nil else {
            throw SpotError.fault("\(name) has an unknown starts: \(manifest.starts ?? ""). Use starts = \"first-launch\".")
        }
        let isFound = (!triggers.answersOnly || !commands.isEmpty) && (offeredActions.isEmpty || triggers.lists)
        var command = Spot(
            id: id,
            name: name,
            url: url,
            kind: .list,
            icon: icon,
            subtitle: manifest.detail,
            triggers: triggers,
            isFound: isFound,
            mode: mode,
            dataName: SpotID(id).name,
            isOnGrid: isFound && commands.isEmpty && triggers.every == nil,
            commands: commands,
            offeredActions: offeredActions,
            settings: manifest.settings,
            views: Dictionary(manifest.views.map { (URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent, Self.path($0, beside: url)) }) { first, _ in first },
            viewDates: Dictionary(manifest.views.map { Self.path($0, beside: url) }.compactMap { view in Self.viewDate(of: view, script: url).map { (view, $0) } }) { first, _ in first },
            sources: sources,
            pages: manifest.pages,
            uses: uses,
            keywords: manifest.keywords,
            sample: Self.sample(beside: url),
            edits: edits,
            starts: starts
        )
        command.actions = manifest.actions
        command.bindings = manifest.bindings
        command.events = manifest.events
        self.init(id: id, spots: [command])
    }

    static func runs(_ url: URL, manifest: Manifest) -> Bool {
        if SpotSample.isScript(url) || !manifest.describes(url.lastPathComponent) { return false }
        if FileManager.default.isExecutableFile(atPath: url.path) { return true }
        return url.pathExtension == inlineExtension && manifest.isWritten
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
