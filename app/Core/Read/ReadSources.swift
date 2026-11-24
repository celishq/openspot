import Foundation

public final class ReadSources: @unchecked Sendable {
    static let limit = 100_000
    private static let finder = (bundleID: "com.apple.finder", name: "Finder")
    private static let finderScript = """
        tell application id "com.apple.finder"
            set found to {}
            repeat with picked in (get selection)
                set end of found to POSIX path of (picked as alias)
            end repeat
            return found
        end tell
        """

    static let accessibility = "accessibility"

    private let mac: any MacReads

    public init(mac: any MacReads) {
        self.mac = mac
    }

    func access(of app: String? = nil, asks: Bool = false) async -> [TextBlock] {
        let apps = Browser.all.map(\.bundleID) + [Self.finder.bundleID]
        var records: [TextBlock] = []
        for bundleID in apps where app == nil || app == bundleID {
            guard let place = mac.place(of: bundleID) else { continue }
            records.append(Self.record([("app", bundleID), ("path", place), ("access", await mac.access(to: bundleID, asks: asks).rawValue)]))
        }
        if app == nil || app == Self.accessibility {
            records.append(Self.record([("app", Self.accessibility), ("access", mac.accessibility(asks: asks).rawValue)]))
        }
        return records
    }

    func tab(asks: Bool) async throws -> [TextBlock] {
        guard let front = await mac.front(), let browser = Browser.all.first(where: { $0.bundleID == front.bundleID }),
              try await allows(browser.bundleID, named: browser.name, asks: asks),
              let values = await mac.run(browser.script), let url = values.first, !url.isEmpty
        else { return [] }
        let title = values.dropFirst().first.flatMap { $0.isEmpty ? nil : $0 }
        return [Self.record([("url", url)] + (title.map { [("title", $0)] } ?? []) + [("app", browser.bundleID)])]
    }

    func finder(asks: Bool) async throws -> [TextBlock] {
        guard try await allows(Self.finder.bundleID, named: Self.finder.name, asks: asks), let files = await mac.run(Self.finderScript), !files.isEmpty else { return [] }
        return [Self.record(files.map { ("file", $0) } + [("app", Self.finder.bundleID)])]
    }

    func selection(asks: Bool) async throws -> [TextBlock] {
        guard mac.accessibility(asks: asks) == .allowed else { throw ReadRefusal(reader: "the selected text") }
        guard let text = await mac.selectedText().map(Self.cut), !text.allSatisfy(\.isWhitespace) else { return [] }
        let app = await mac.front()?.bundleID
        return [Self.record([("text", text)] + (app.map { [("app", $0)] } ?? []))]
    }

    private func allows(_ bundleID: String, named name: String, asks: Bool) async throws -> Bool {
        switch await mac.access(to: bundleID, asks: asks) {
        case .allowed: true
        case .unknown: false
        case .denied, .unasked: throw ReadRefusal(reader: name)
        }
    }

    private static func cut(_ text: String) -> String {
        guard text.utf8.count > limit else { return text }
        return String(text[..<text.utf8.index(text.utf8.startIndex, offsetBy: limit)])
    }

    private static func record(_ fields: [(String, String)]) -> TextBlock {
        TextBlock(fields: fields.map { TextBlock.Field(key: $0.0, value: $0.1) })
    }
}
