import Foundation

public struct PanelState: Equatable, Sendable {
    public static let keys = ["open", "text", "sheet", "route", "selected", "menu", "chips", "moving"]

    public let values: [String: String]

    public init(values: [String: String] = [:]) {
        self.values = values
    }

    public var lines: String {
        Self.keys.map { "\($0)=\(values[$0] ?? "")\n" }.joined()
    }

    public var json: String {
        let data = (try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])) ?? Data()
        return (String(data: data, encoding: .utf8) ?? "{}") + "\n"
    }

    public func missing(_ facts: [(key: String, value: String)]) -> String? {
        facts.first { values[$0.key] != $0.value }.map { "\($0.key)=\($0.value)" }
    }
}
