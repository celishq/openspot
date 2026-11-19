import Foundation

public struct RaycastImport: Sendable {
    public enum Outcome: String, Encodable, Sendable {
        case added
        case kept
        case skipped
    }

    public struct Item: Equatable, Encodable, Sendable, PrintedRecord {
        public let file: String
        public let title: String?
        public let id: String?
        public let outcome: Outcome
        public let reason: String?

        var blocks: [[(String, String?)]] {
            [[("row", id ?? file), ("title", title ?? file), ("detail", reason ?? outcome.rawValue), ("outcome", outcome.rawValue), ("file", file)]]
        }
    }

    public let folder: URL

    static let depth = 4
    static let fileLimit = 1024 * 1024
    static let skippedFolders: Set<String> = ["node_modules", "images", "assets"]

    public init(folder: URL) {
        self.folder = folder
    }

    public func run(into spots: URL, taken: Set<String>, isDry: Bool, skip: Set<String> = []) throws -> [Item] {
        guard FileManager.default.fileExists(atPath: folder.path) else { throw SpotError.failed(1, "There is no folder \(folder.path).") }
        var used = taken
        var items: [Item] = []
        let files = scan()
        var parsed: [URL: Result<RaycastScript, RaycastScript.Skip>] = [:]
        for file in files {
            do throws(RaycastScript.Skip) {
                parsed[file] = .success(try RaycastScript(text: Self.head(of: file), name: file.lastPathComponent))
            } catch {
                parsed[file] = .failure(error)
            }
        }
        let helpers = Dictionary(grouping: files.filter { parsed[$0].map(Self.isHelper) == true }) { $0.deletingLastPathComponent() }
        for file in files {
            let relative = String(file.path.dropFirst(folder.path.count + 1))
            guard case .success(let script) = parsed[file] else {
                if case .failure(let skip) = parsed[file] { items.append(Item(file: relative, title: nil, id: nil, outcome: .skipped, reason: skip.reason)) }
                continue
            }
            if skip.contains(relative) {
                items.append(Item(file: relative, title: script.title, id: nil, outcome: .skipped, reason: "Left out"))
                continue
            }
            let place = Self.place(of: script, source: file, in: spots, used: used)
            used.insert(place.name)
            if place.isKept {
                items.append(Item(file: relative, title: script.title, id: place.name, outcome: .kept, reason: "already imported"))
                continue
            }
            let icon = Self.icon(of: script, source: file)
            let spot = RaycastSpot(script: script, source: file, name: place.name, icon: icon.name, iconCopy: icon.copy, helpers: helpers[file.deletingLastPathComponent()] ?? [])
            if !isDry { _ = try spot.write(in: spots) }
            items.append(Item(file: relative, title: script.title, id: place.name, outcome: .added, reason: nil))
        }
        return items
    }

    func scan() -> [URL] {
        let manager = FileManager.default
        guard let walk = manager.enumerator(atPath: folder.resolvingSymlinksInPath().path) else { return [] }
        var files: [URL] = []
        while let relative = walk.nextObject() as? String {
            let file = folder.appendingPathComponent(relative)
            let name = file.lastPathComponent
            var isFolder: ObjCBool = false
            let exists = manager.fileExists(atPath: file.path, isDirectory: &isFolder)
            if isFolder.boolValue {
                if name.hasPrefix(".") || Self.skippedFolders.contains(name) || walk.level >= Self.depth { walk.skipDescendants() }
                continue
            }
            let size = (try? manager.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0
            guard exists, !name.hasPrefix("."), size <= Self.fileLimit else { continue }
            files.append(file)
        }
        return files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    static func isHelper(_ result: Result<RaycastScript, RaycastScript.Skip>) -> Bool {
        guard case .failure(.notScript) = result else { return false }
        return true
    }

    static func head(of file: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return "" }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: RaycastScript.headerLimit)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    static func place(of script: RaycastScript, source: URL, in spots: URL, used: Set<String>) -> (name: String, isKept: Bool) {
        let base = name(of: script.title) ?? name(of: source.deletingPathExtension().lastPathComponent) ?? "script"
        let original = try? Data(contentsOf: source.resolvingSymlinksInPath())
        for number in 1... {
            let name = number == 1 ? base : "\(base)-\(number)"
            let folder = spots.appendingPathComponent("\(name).spot", isDirectory: true)
            let copy = folder.appendingPathComponent(RaycastSpot.folder).appendingPathComponent(source.lastPathComponent)
            if let original, (try? Data(contentsOf: copy)) == original { return (name, true) }
            if !used.contains(name), !FileManager.default.fileExists(atPath: folder.path) { return (name, false) }
        }
        return (base, false)
    }

    static func name(of text: String) -> String? {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US")).lowercased()
        let name = folded.replacing(/[^a-z0-9]+/, with: "-").trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return name.isEmpty ? nil : String(name.prefix(48)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    static func icon(of script: RaycastScript, source: URL) -> (name: String, copy: URL?) {
        guard let icon = script.icon else { return (RaycastSpot.defaultIcon, nil) }
        if icon.hasPrefix("https://") { return (icon, nil) }
        let kind = (icon as NSString).pathExtension.lowercased()
        guard icon.contains("/") || ["png", "jpg", "jpeg"].contains(kind) else { return (icon, nil) }
        let path = (icon as NSString).expandingTildeInPath
        let file = path.hasPrefix("/") ? URL(fileURLWithPath: path) : source.deletingLastPathComponent().appendingPathComponent(path)
        guard ["png", "jpg", "jpeg"].contains(kind), FileManager.default.fileExists(atPath: file.path) else { return (RaycastSpot.defaultIcon, nil) }
        return ("\(RaycastSpot.iconFile).\(kind)", file)
    }
}
