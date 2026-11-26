import Foundation

extension AttachmentValue.Kind: Codable {
    static func value(in fields: [TextBlock.Field]) -> (kind: Self, values: [String])? {
        let kinds = Set(fields.compactMap { Self(rawValue: $0.key) })
        guard kinds.count == 1, let kind = kinds.first else { return nil }
        let values = fields.filter { $0.key == kind.rawValue }.map(\.value)
        return kind == .file || values.count == 1 ? (kind, values) : nil
    }

    func fields(_ values: [String]) -> [TextBlock.Field] {
        values.map { TextBlock.Field(key: rawValue, value: $0) }
    }
}
