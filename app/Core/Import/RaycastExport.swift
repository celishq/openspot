import Foundation

public struct RaycastExport: Equatable, Sendable {
    public struct Quicklink: Equatable, Codable, Sendable {
        public let title: String
        public let url: String
        public let app: String?
    }

    public struct Snippet: Equatable, Codable, Sendable {
        public let title: String
        public let text: String
        public let keyword: String?
    }

    public struct Rest: Equatable, Codable, Sendable {
        public var hotkeys = 0
        public var aliases = 0
        public var favorites = 0
        public var clips = 0

        public init(hotkeys: Int = 0, aliases: Int = 0, favorites: Int = 0, clips: Int = 0) {
            self.hotkeys = hotkeys
            self.aliases = aliases
            self.favorites = favorites
            self.clips = clips
        }
    }

    public let quicklinks: [Quicklink]
    public let snippets: [Snippet]
    public let rest: Rest

    public init(quicklinks: [Quicklink] = [], snippets: [Snippet] = [], rest: Rest = Rest()) {
        self.quicklinks = quicklinks
        self.snippets = snippets
        self.rest = rest
    }

    init(json: [String: Any]) {
        let packed = json["quicklinks"] as? [String: Any]
        let platforms = Dictionary((packed?["openWithPlatforms"] as? [[String: Any]] ?? []).compactMap { platform in
            (platform["id"] as? String).flatMap { id in (platform["macos"] as? String).map { (id, $0) } }
        }) { first, _ in first }
        let links = packed?["quicklinks"] as? [[String: Any]] ?? json["quicklinks"] as? [[String: Any]] ?? []
        quicklinks = links.compactMap { link in
            guard let url = link["link"] as? String, !url.isEmpty else { return nil }
            let app = (link["openWith"] as? String).map { platforms[$0] ?? $0 }
            return Quicklink(title: link["name"] as? String ?? url, url: Self.placeholders(url), app: app?.hasPrefix("/") == true ? app : nil)
        }
        let first = json["builtin_package_snippets"] as? [String: Any]
        let texts = (json["snippets"] as? [String: Any])?["snippets"] as? [[String: Any]] ?? first?["snippets"] as? [[String: Any]] ?? []
        snippets = texts.compactMap { snippet in
            guard let text = snippet["text"] as? String, let title = (snippet["title"] ?? snippet["name"]) as? String else { return nil }
            let keyword = (snippet["keyword"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return Snippet(title: title, text: text, keyword: keyword)
        }
        var rest = Rest()
        let commands = (json["settings"] as? [String: Any])?["commands"] as? [[String: Any]] ?? []
        rest.hotkeys = commands.filter { $0["macosHotkey"] != nil }.count
        rest.aliases = commands.filter { ($0["alias"] as? String)?.isEmpty == false }.count
        rest.favorites = commands.filter { $0["favoriteOrder"] != nil }.count
        rest.clips = ((json["clipboardHistory"] as? [String: Any])?["clipboardEntries"] as? [Any])?.count ?? 0
        self.rest = rest
    }

    public static func read(_ data: Data, passphrase: String) throws -> RaycastExport {
        let json: Data
        do {
            json = try RaycastCipher.open(data, passphrase: passphrase)
        } catch {
            throw SpotError.failed(1, error.reason)
        }
        guard let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else {
            throw SpotError.failed(1, RaycastCipher.Fault.notExport.reason)
        }
        return RaycastExport(json: object)
    }

    static func placeholders(_ url: String) -> String {
        url.replacing(/\{(?:[Qq]uery|argument)(?:\s[^}]*)?\}/) { _ in "{query}" }
    }
}
