import Foundation

public struct SpotFile: Equatable, Sendable {
    public static let inlineExtension = "js"

    public let id: String
    public let spots: [Spot]

    public init(id: String, spots: [Spot]) {
        self.id = id
        self.spots = spots
    }

    public init?(file url: URL, id: String) throws {
        if SwiftProgram.isProgram(url) { return nil }
        if Self.runs(url) {
            try self.init(script: url, header: SpotHeader(url: url).block, id: id)
        } else {
            return nil
        }
    }

    public init(script url: URL, header: TextBlock, id: String) throws {
        let name = header.value(HeaderKey.title) ?? Self.name(of: url)
        if let key = HeaderKey.unknown(in: header) {
            throw SpotError.fault("\(name) has an unknown key in its header: \(key)")
        }
        for block in header.children {
            guard let key = HeaderBlock.unknown(in: block), let kind = HeaderBlock(block: block) else { continue }
            throw SpotError.fault("\(name) has an unknown key on the \(kind.rawValue) \(block.value(kind) ?? ""): \(key)")
        }
        if header.fields.contains(where: { HeaderKey.isDrawing($0.key) }) {
            self.init(id: id, spots: [try Self.drawn(header, name: name, id: id, url: url)])
            return
        }
        let icon = Icon(text: header.value(HeaderKey.icon))
        let symbol = icon?.symbol
        let on = try SpotRead(on: header.values(HeaderKey.on), of: name)
        let read = on?.moments.isEmpty == false ? on : nil
        let emits = SpotRead.words(header.value(HeaderKey.emits))
        if let word = emits.first(where: { !SpotEvent.isName($0) }) {
            throw SpotError.fault("\(name) has an unknown event in its emits: \(word). Write a word with a dot, such as emits=music.track")
        }
        let uses = try SpotUse.set(header.value(HeaderKey.uses), of: name)
        let isInline = url.pathExtension == Self.inlineExtension && !FileManager.default.isExecutableFile(atPath: url.path)
        let modeName = header.value(HeaderKey.mode) ?? SpotMode.once.rawValue
        guard let named = SpotMode(rawValue: modeName), named != .inline else {
            throw SpotError.fault("\(name) has an unknown mode: \(modeName). Use once, stay or always")
        }
        if isInline, named != .once {
            throw SpotError.fault("\(name) is a .js file, which runs inline, so it takes no mode=\(modeName)")
        }
        let mode = isInline ? SpotMode.inline : named
        let namedPlaces = try Place.read(header.values(HeaderKey.offers), of: name)
        let answers = on?.answers
        let answersOnly = answers != nil && read == nil
        if let field = header.children.compactMap({ $0.value(HeaderBlock.field) }).first(where: ReservedSetting.isReserved) {
            throw SpotError.fault("\(name) has field=\(field), a key that Openspot keeps for the person. Give the field another name.")
        }
        let buttons = header.children.filter { HeaderBlock(block: $0) == .button }
        let offeredActions = try OfferedAction.read(buttons, owner: id, of: name, isInline: mode == .inline)
        let offeredIDs = Set(offeredActions.map(\.action.id))
        let offers = try buttons.filter { !offeredIDs.contains($0.value(HeaderBlock.button) ?? "") }.map { block in
            guard let offer = CommandOffer(block: block) else {
                throw SpotError.fault("\(name) cannot read the button \(block.value(HeaderBlock.button) ?? ""). Give it an ID with no space and a title, such as button=left with title=Left side")
            }
            return offer
        }
        let press = header.value(HeaderKey.press) ?? "sheet"
        guard ["sheet", "open"].contains(press) else { throw SpotError.fault("\(name) has an unknown press: \(press). Use open or sheet") }
        let view = header.value(HeaderKey.view)
        if let view, URL(fileURLWithPath: view).pathExtension != SwiftProgram.sourceExtension {
            throw SpotError.fault("\(name) needs a Swift file for its view, such as view=\(url.deletingPathExtension().lastPathComponent).swift")
        }
        let edits = header.value(HeaderKey.edits)
        guard edits == nil || edits == "spots" else { throw SpotError.fault("\(name) has an unknown edits: \(edits!). Use edits=spots") }
        let places: Set<Place> = namedPlaces ?? (offeredActions.isEmpty && !answersOnly ? [.card] : [])
        let kind: SpotKind = mode.stays || places.contains(.search) || read?.has(.sheet) == true || read?.seconds != nil ? .list : .launch
        try Place.check(places, read: read, mode: mode, kind: kind, of: name)
        let command = Spot(
            id: id,
            name: name,
            url: url,
            kind: kind,
            symbol: symbol ?? "app",
            subtitle: header.value(HeaderKey.detail),
            read: read,
            isFound: !answersOnly,
            answers: answers,
            mode: mode,
            pressRuns: press == "open",
            drop: header.value(HeaderKey.drop)?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? [],
            offeredPlaces: places,
            dataName: SpotID(id).name,
            isOnGrid: places.contains(.card) && offers.isEmpty && read?.seconds == nil && !answersOnly,
            headerSymbol: symbol,
            offers: offers,
            offeredActions: offeredActions,
            settings: header.children.filter { HeaderBlock(block: $0) == .field }.compactMap { CommandOffer(setting: $0) },
            file: icon?.file.map { Self.path($0, beside: url) },
            image: icon?.image.map { Self.path($0, beside: url) },
            glyph: icon?.glyph,
            view: view.map { Self.path($0, beside: url) },
            viewDate: view.flatMap { Self.viewDate(of: Self.path($0, beside: url), script: url) },
            emits: emits,
            pages: header.values(HeaderKey.pages),
            uses: uses,
            keywords: header.list(HeaderKey.keywords),
            sample: Self.sample(beside: url),
            editsSpots: edits != nil
        )
        self.init(id: id, spots: [command])
    }

    static func runs(_ url: URL) -> Bool {
        if SpotSample.isScript(url) { return false }
        if FileManager.default.isExecutableFile(atPath: url.path) { return true }
        return url.pathExtension == inlineExtension && !SpotHeader(url: url).block.fields.isEmpty
    }

    private static func sample(beside url: URL) -> URL? {
        let sample = SpotSample.script(beside: url)
        return SpotSample.isScript(sample) && FileManager.default.isExecutableFile(atPath: sample.path) ? sample : nil
    }

    private static func viewDate(of view: String, script: URL) -> Date? {
        let folder = script.deletingLastPathComponent().path
        let isLinked = (try? FileManager.default.destinationOfSymbolicLink(atPath: folder)) != nil
        guard (view as NSString).deletingLastPathComponent == folder, !isLinked else { return nil }
        return [view, ViewLibrary.path(beside: view)].compactMap { try? FileManager.default.attributesOfItem(atPath: $0)[.modificationDate] as? Date }.max()
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

    private static func drawn(_ header: TextBlock, name: String, id: String, url: URL) throws -> Spot {
        if let key = header.fields.map(\.key).first(where: { key in !HeaderKey.isDrawing(key) && !HeaderKey.card.contains { $0.rawValue == key } }) {
            throw SpotError.fault("\(name) draws a card of other spots, so it takes no \(key). Keep title, icon, detail, keywords, to and its grid lines, or draw its own blocks with grid lines in its output")
        }
        let keys = Set(header.fields.map(\.key).filter(HeaderKey.isDrawing))
        guard keys.count == 1, let key = keys.first else {
            throw SpotError.fault("\(name) draws its card at more than one size. Keep the grid lines of one size, such as grid.large")
        }
        let sizeName = String(key.dropFirst(HeaderKey.drawing.count))
        guard let size = SpotSize(name: sizeName) else { throw SpotError.fault("\(name) has an unknown size: \(sizeName)") }
        let drawing = header.values(key)
        if let fault = WidgetLayout.faults(in: drawing).first { throw SpotError.fault("\(name): \(fault)") }
        let layout = WidgetLayout(drawing: drawing, size: size)
        let icon = Icon(text: header.value(HeaderKey.icon))
        return Spot(
            id: id,
            name: name,
            url: url,
            kind: .widget,
            size: layout.size,
            symbol: icon?.symbol ?? "app",
            subtitle: header.value(HeaderKey.detail),
            layout: layout,
            places: layout.names.map { tool($0, beside: url, id: id) },
            opens: header.value(HeaderKey.to).map { tool($0, beside: url, id: id) }
        )
    }

    private static func tool(_ name: String, beside url: URL, id: String) -> String {
        guard !name.contains("/") else { return name }
        let files = (try? FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)) ?? []
        let own = files.first { $0.deletingPathExtension().lastPathComponent == name && $0.lastPathComponent != url.lastPathComponent
            && (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true && runs($0) }
        return own.map { SpotID(file: $0).description } ?? name
    }
}
