import Foundation

public struct FieldValue: Equatable, Sendable {
    public let preview: ContextPreview?
    public let lines: Int

    public init(_ preview: ContextPreview? = nil) {
        self.preview = preview
        lines = preview.map { SpotTokens.contextValueLines(of: $0.text) } ?? 0
    }
}
