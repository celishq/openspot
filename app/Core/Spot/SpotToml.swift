import Foundation

public struct SpotToml: Equatable, Sendable {
    public static let fileName = "spot.toml"
    static let limit = 65_536
    private static let lists: Set<String> = ["uses", "emits", "keywords"]
    private static let kinds: [String: HeaderBlock] = ["commands": .button, "settings": .field]
    private static let scripts = "scripts"

    public let isWritten: Bool
    private let main: String?
    private let blocks: [String: TextBlock]
    private let fault: String?

    public init(text: String?, folder: String) {
        let name = (folder as NSString).lastPathComponent
        main = (name as NSString).pathExtension == SpotPackage.fileExtension ? (name as NSString).deletingPathExtension : nil
        isWritten = text != nil
        do {
            guard (text?.utf8.count ?? 0) <= Self.limit else {
                throw SpotError.fault("\(Self.fileName) is over \(Self.limit / 1024) KB. Keep it shorter.")
            }
            blocks = try text.map(Self.blocks) ?? [:]
            fault = nil
        } catch {
            blocks = [:]
            fault = (error as? SpotError)?.reason ?? String(describing: error)
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

    public func describes(_ script: String) -> Bool {
        fault != nil || key(of: script).isEmpty || blocks[key(of: script)] != nil
    }

    public func block(of script: String) throws -> TextBlock {
        if let fault { throw SpotError.fault("\(SpotFile.name(of: URL(fileURLWithPath: script))) cannot load: \(fault)") }
        return blocks[key(of: script)] ?? TextBlock(fields: [])
    }

    public func block(of script: URL) throws -> TextBlock {
        try block(of: script.lastPathComponent)
    }

    private func key(of script: String) -> String {
        let stem = ((script as NSString).lastPathComponent as NSString).deletingPathExtension
        return main == nil || stem == main ? "" : stem
    }

    private static func blocks(_ text: String) throws -> [String: TextBlock] {
        let document: ConfigDocument
        do {
            document = try ConfigDocument(text: text)
        } catch {
            throw SpotError.fault("\(fileName), \((error as? SpotError)?.reason ?? String(describing: error))")
        }
        var fields: [String: [TextBlock.Field]] = ["": try document.keys.flatMap { try Self.fields($0, document.values[$0]) }]
        var children: [String: [TextBlock]] = [:]
        fields[""]? += document.tables.map { TextBlock.Field(key: $0.name, value: "") }
        for section in document.sections {
            var path = Self.path(section.name)
            var script = ""
            if path.first == Self.scripts, path.count > 1 {
                script = path[1]
                path.removeFirst(2)
            }
            let own = try section.keys.flatMap { try Self.fields($0, section[$0]) }
            if path.isEmpty {
                fields[script, default: []] += own
            } else if path.count == 2, let kind = kinds[path[0]] {
                fields[script, default: []] += []
                children[script, default: []].append(TextBlock(fields: [TextBlock.Field(key: kind.rawValue, value: path[1])] + own))
            } else {
                fields[script, default: []].append(TextBlock.Field(key: path[0], value: ""))
            }
        }
        return Dictionary(uniqueKeysWithValues: fields.map { ($0.key, TextBlock(fields: $0.value, children: children[$0.key] ?? [])) })
    }

    private static func fields(_ name: String, _ value: ConfigDocument.Value?) throws -> [TextBlock.Field] {
        let key = path(name).joined(separator: ".")
        let texts: [String]
        switch value {
        case .string(let text): texts = [text]
        case .boolean(let isOn): texts = [String(isOn)]
        case .integer(let number): texts = [String(number)]
        case .number(let number): texts = [String(number)]
        case .strings(let items): texts = lists.contains(key) ? [items.joined(separator: ", ")] : items
        case .table, nil: throw SpotError.fault("\(fileName): \(key) holds a table. Write a text, such as \(key) = \"…\", or a list of texts.")
        }
        return texts.map { TextBlock.Field(key: key, value: $0) }
    }

    private static func path(_ name: String) -> [String] {
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
