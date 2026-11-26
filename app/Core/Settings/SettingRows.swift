import Foundation

public struct SettingRows: Equatable, Sendable {
    public struct Group: Identifiable, Equatable, Sendable {
        public let id: String
        public let rows: [SettingRow]
    }

    public private(set) var all: [SettingRow] = []

    public init() {}

    init(_ rows: [SettingRow]) {
        all = rows
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

    public func groups(of spot: String) -> [Group] {
        let rows = rows(of: spot)
        let kinds: [(String, Set<SettingRow.Kind>)] = [("Shortcuts", [.key]), ("Settings", [.field, .text, .secret, .choice]), ("Where It Shows", [.toggle])]
        return kinds.map { title, kinds in Group(id: title, rows: rows.filter { kinds.contains($0.kind) }) }.filter { !$0.rows.isEmpty }
    }
}
