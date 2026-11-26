import Foundation

public struct Manifest: Equatable, Sendable {
    public static let fileName = "spot.toml"
    public static let keys: Set<String> = [
        "title", "icon", "detail", "keywords", "edits", "starts", "views", "source", "uses", "pages", "answers", "stay"
    ]
    public static let tables: Set<String> = [Setting.table, Action.table, Binding.table, Event.table, RowType.table, Triggers.table]
    static let appKeys: Set<String> = ["edits", "starts"]
    static let limit = 65_536
    static let scriptsTable = "scripts"
    private static let stayKey = "stay"

    private struct Script {
        var values: [String: [String]] = [:]
        var written: [String] = []
        var settings: [Setting] = []
        var actions: [Action] = []
        var bindings: [Binding] = []
        var events: [Event] = []
        var types: [RowType] = []
        var triggers = Triggers()

        mutating func take(_ table: [(String, ConfigDocument.Value?)]) throws {
            for (name, value) in table {
                let key = Manifest.path(name).joined(separator: ".")
                if key == Manifest.stayKey, case .boolean = value {} else if key == Manifest.stayKey {
                    throw SpotError.fault("\(Manifest.fileName): stay takes true or false, such as stay = true.")
                }
                written.append(key)
                values[key, default: []] += try Manifest.texts(key, value).filter { !$0.isEmpty }
            }
        }
    }

    public let isWritten: Bool
    public let title: String?
    public let icon: String?
    public let detail: String?
    public let keywords: [String]
    public let edits: String?
    public let starts: String?
    public let views: [String]
    public let source: [String]
    public let uses: [String]
    public let pages: [String]
    public let answers: String?
    public let settings: [Setting]
    public let actions: [Action]
    public let bindings: [Binding]
    public let events: [Event]
    public let types: [RowType]
    public let stay: Bool?
    public let triggers: Triggers
    private let written: [String]
    let hasScripts: Bool
    private let scripts: [String: Manifest]
    private let main: String?
    private let fault: String?

    public init(text: String?, folder: String) {
        let name = (folder as NSString).lastPathComponent
        let main = (name as NSString).pathExtension == SpotPackage.fileExtension ? (name as NSString).deletingPathExtension : nil
        do {
            guard (text?.utf8.count ?? 0) <= Self.limit else {
                throw SpotError.fault("\(Self.fileName) is over \(Self.limit / 1024) KB. Keep it shorter.")
            }
            var scripts = try text.map(Self.scripts) ?? [:]
            let top = scripts.removeValue(forKey: "") ?? Script()
            let others = scripts.mapValues { Manifest($0, scripts: [:], isWritten: true, main: nil, fault: nil) }
            self.init(top, scripts: others, isWritten: text != nil, main: main, fault: nil)
        } catch {
            self.init(Script(), scripts: [:], isWritten: text != nil, main: main, fault: (error as? SpotError)?.reason ?? String(describing: error))
        }
    }

    public init(folder: URL) {
        let file = try? FileHandle(forReadingFrom: folder.appendingPathComponent(Self.fileName))
        defer { try? file?.close() }
        let data = file.map { (try? $0.read(upToCount: Self.limit + 1)) ?? Data() }
        self.init(text: data.map { String(decoding: $0, as: UTF8.self) }, folder: folder.path)
    }

    public init(beside script: URL) {
        self.init(folder: script.deletingLastPathComponent())
    }

    private init(_ script: Script, scripts: [String: Manifest], isWritten: Bool, main: String?, fault: String?) {
        let text = { (key: String) in script.values[key]?.first }
        let list = { (key: String) in script.values[key] ?? [] }
        self.isWritten = isWritten
        title = text("title")
        icon = text("icon")
        detail = text("detail")
        keywords = list("keywords").flatMap { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }.filter { !$0.isEmpty }
        edits = text("edits")
        starts = text("starts")
        views = list("views")
        source = list("source")
        uses = list("uses").flatMap(Self.words)
        pages = list("pages")
        answers = text("answers")
        settings = script.settings
        actions = script.actions
        bindings = script.bindings
        events = script.events
        types = script.types
        stay = text(Self.stayKey).flatMap(Bool.init)
        triggers = script.triggers
        written = script.written
        hasScripts = !scripts.isEmpty
        self.scripts = scripts
        self.main = main
        self.fault = fault
    }

    public func describes(_ script: String) -> Bool {
        fault != nil || key(of: script).isEmpty || scripts[key(of: script)] != nil
    }

    public func script(_ script: String) throws -> Manifest {
        if let fault { throw SpotError.fault("\(SpotFile.name(of: URL(fileURLWithPath: script))) cannot load: \(fault)") }
        let key = key(of: script)
        return key.isEmpty ? self : scripts[key] ?? Manifest(text: nil, folder: "")
    }

    public func script(_ script: URL) throws -> Manifest {
        try self.script(script.lastPathComponent)
    }

    func unknownKey(isApp: Bool) -> String? {
        written.first { !Self.keys.contains($0) || !isApp && Self.appKeys.contains($0) }
    }

    private func key(of script: String) -> String {
        let stem = ((script as NSString).lastPathComponent as NSString).deletingPathExtension
        return main == nil || stem == main ? "" : stem
    }

    private static func scripts(_ text: String) throws -> [String: Script] {
        let document: ConfigDocument
        do {
            document = try ConfigDocument(text: text)
        } catch {
            throw SpotError.fault("\(fileName), \((error as? SpotError)?.reason ?? String(describing: error))")
        }
        var top = Script()
        try top.take(document.keys.map { ($0, document.values[$0]) })
        top.written += document.tables.map(\.name)
        var scripts = ["": top]
        for section in document.sections {
            var path = Self.path(section.name)
            var name = ""
            if path.first == scriptsTable, path.count > 1 {
                name = path[1]
                path.removeFirst(2)
            }
            var script = scripts[name] ?? Script()
            let heading = "[\(section.name)]"
            var table = Script()
            let isTyped = path == [Setting.table] || path == [Triggers.table] || path == [Binding.table] || path.count == 2 && (path[0] == Action.table || path[0] == Event.table || path[0] == RowType.table)
            if !isTyped { try table.take(section.keys.map { ($0, section[$0]) }) }
            if path == [Setting.table] {
                script.settings += try section.keys.map { key in
                    guard Setting.isKey(key) else { throw SpotError.fault("\(fileName): \(heading) has a key with a space: \(key).") }
                    return Setting(try Parameter(name: key, value: section[key], keys: Parameter.settingKeys, place: "\(heading) \(key)"))
                }
            } else if path == [Binding.table] {
                script.bindings += try section.keys.map { try Binding(name: $0, value: section[$0], section: heading) }
            } else if path.count == 2, path[0] == Event.table {
                script.events.append(try Event(name: path[1], section: heading, table: section))
            } else if path.count == 2, path[0] == RowType.table {
                script.types.append(try RowType(name: path[1], section: heading, table: section))
            } else if path == [Triggers.table] {
                script.triggers = try Triggers(section: heading, table: section)
            } else if path.count == 2, path[0] == Action.table {
                script.actions.append(try Action(id: path[1], section: heading, table: section))
            } else if path.isEmpty {
                script.values.merge(table.values) { $0 + $1 }
                script.written += table.written
            } else {
                script.written.append(path[0])
            }
            scripts[name] = script
        }
        return scripts
    }

    private static func texts(_ key: String, _ value: ConfigDocument.Value?) throws -> [String] {
        switch value {
        case .string(let text): [text]
        case .boolean(let isOn): [String(isOn)]
        case .integer(let number): [String(number)]
        case .number(let number): [String(number)]
        case .strings(let items): items
        case .table, nil: throw SpotError.fault("\(fileName): \(key) holds a table. Write a text, such as \(key) = \"…\", or a list of texts.")
        }
    }

    private static func words(_ text: String) -> [String] {
        text.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
    }

    static func path(_ name: String) -> [String] {
        var parts = [""]
        var quote: Character?
        for character in name {
            if character == quote {
                quote = nil
            } else if quote == nil, character == "\"" || character == "'" {
                quote = character
            } else if quote == nil, character == "." {
                parts.append("")
            } else {
                parts[parts.count - 1].append(character)
            }
        }
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
