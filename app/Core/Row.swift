import Foundation

public struct Row: Equatable, Decodable, Sendable {
    public let title: String
    public let subtitle: String?
    public let run: String
}

public struct RowResult: Equatable, Sendable {
    public var rows: [Row]
    public var errors: [String]

    public init(rows: [Row] = [], errors: [String] = []) {
        self.rows = rows
        self.errors = errors
    }
}

public enum RowParser {
    public static func parse(_ output: String) -> RowResult {
        var result = RowResult()
        let decoder = JSONDecoder()
        for line in output.split(separator: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            do {
                result.rows.append(try decoder.decode(Row.self, from: Data(line.utf8)))
            } catch {
                result.errors.append(String(line))
            }
        }
        return result
    }
}
