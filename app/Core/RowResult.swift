import Foundation

public struct RowResult: Equatable, Sendable {
    public private(set) var rows: [Row] = []
    public private(set) var errors: [String] = []

    public init(output: String) {
        let decoder = JSONDecoder()
        for line in output.split(separator: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            if let row = try? decoder.decode(Row.self, from: Data(line.utf8)) {
                rows.append(row)
            } else {
                errors.append(String(line))
            }
        }
    }
}
