import Foundation

public struct SettingRows: Equatable, Sendable {
    public struct Group: Identifiable, Equatable, Sendable {
        public let id: String
        public let rows: [SettingRow]
    }

    public private(set) var all: [SettingRow] = []
    public private(set) var clashing: Set<String> = []
    private var clashes: [[SettingRow]] = []

    public init() {}

    init(_ rows: [SettingRow]) {
        all = rows
        let keyed = rows.filter { $0.kind == .key && !($0.value ?? "").isEmpty }
        clashes = Dictionary(grouping: keyed) { Self.normal($0.value ?? "") }.values.filter { $0.count > 1 }.sorted { ($0[0].value ?? "") < ($1[0].value ?? "") }
        clashing = Set(clashes.flatMap { $0.map(\.item) })
    }

    public func clash(of item: String) -> String? {
        let others = clashes.first { $0.contains { $0.item == item } }?.filter { $0.item != item } ?? []
        return others.isEmpty ? nil : "Also " + others.map { "\($0.name) · \($0.title)" }.joined(separator: ", ")
    }

    private static func normal(_ key: String) -> String {
        let words = key.lowercased().split(separator: "+").map(String.init)
        return (words.dropLast().sorted() + words.suffix(1)).joined(separator: "+")
    }

    public func row(_ item: String) -> SettingRow? {
        all.first { $0.item == item }
    }

    public func rows(of spot: String) -> [SettingRow] {
        all.filter { $0.spot == spot }
    }

    public func rows(in section: SettingsPage.Section) -> [SettingRow] {
        all.filter { $0.spot == ReservedSetting.appSpot && $0.section == section }
    }

    public static let attachmentGroup = "Attachment"

    public func groups(of spot: String) -> [Group] {
        let all = rows(of: spot)
        let attachment = all.filter { $0.key == ReservedSetting.attachment }
        let rows = all.filter { $0.key != ReservedSetting.attachment }
        let kinds: [(String, Set<SettingRow.Kind>)] = [("Shortcuts", [.key]), ("Settings", [.field, .text, .secret, .choice]), ("Where It Shows", [.toggle])]
        let groups = kinds.map { title, kinds in Group(id: title, rows: rows.filter { kinds.contains($0.kind) }) }
        return (groups.prefix(1) + [Group(id: Self.attachmentGroup, rows: attachment)] + groups.dropFirst()).filter { !$0.rows.isEmpty }
    }
}
