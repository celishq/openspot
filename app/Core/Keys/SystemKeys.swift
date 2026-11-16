import Foundation

public struct SystemKeys: Sendable {
    private static let uses: [Int: String] = [
        60: "switches to the previous input source", 61: "switches to the next input source", 64: "opens Spotlight", 65: "opens a Finder search"
    ]
    private static let masks: [(mask: Int, modifier: Shortcut.Modifiers)] = [
        (131072, .shift), (262144, .control), (524288, .option), (1048576, .command)
    ]

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static func standard(home: URL) -> SystemKeys {
        SystemKeys(url: home.appendingPathComponent("Library/Preferences/com.apple.symbolichotkeys.plist"))
    }

    public func read() -> [TakenKey] {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let entries = plist["AppleSymbolicHotKeys"] as? [String: Any] else { return [] }
        return entries.compactMap { id, entry in Int(id).map { ($0, entry) } }
            .sorted { $0.0 < $1.0 }
            .compactMap { id, entry in Self.taken(id: id, entry: entry) }
    }

    private static func taken(id: Int, entry: Any) -> TakenKey? {
        guard let use = uses[id],
              let entry = entry as? [String: Any],
              (entry["enabled"] as? NSNumber)?.boolValue == true,
              let value = entry["value"] as? [String: Any],
              let parameters = value["parameters"] as? [Any], parameters.count >= 3,
              let code = (parameters[1] as? NSNumber)?.intValue,
              let mask = (parameters[2] as? NSNumber)?.intValue,
              code >= 0, code <= Int(UInt32.max) else { return nil }
        let modifiers = masks.reduce(into: Shortcut.Modifiers()) { held, entry in
            if mask & entry.mask != 0 { held.insert(entry.modifier) }
        }
        return Shortcut(code: UInt32(code), modifiers: modifiers).map { TakenKey(shortcut: $0, use: use) }
    }
}
