import Foundation

public enum PrintForm: Hashable, Sendable {
    case json
    case frame

    static let frameWord = "--frame"

    func text(of record: some PrintedRecord) throws -> String {
        switch self {
        case .json: try Self.json(record)
        case .frame: record.blocks.map(Self.block).joined()
        }
    }

    func text(of records: [some PrintedRecord]) throws -> String {
        switch self {
        case .json: try Self.json(records)
        case .frame: records.flatMap(\.blocks).map { Self.block($0) + "\n" }.joined()
        }
    }

    static func json(_ value: some Encodable, dates: JSONEncoder.DateEncodingStrategy = .deferredToDate) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = dates
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self) + "\n"
    }

    private static func block(_ pairs: [(String, String?)]) -> String {
        TextBlock(fields: pairs.compactMap { key, value in value.map { TextBlock.Field(key: key, value: $0) } }).text
    }
}
