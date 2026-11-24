import Foundation

public struct FieldValue: Equatable, Sendable {
    public let preview: AttachmentPreview?
    public let lines: Int

    public init(_ preview: AttachmentPreview? = nil) {
        self.preview = preview
        lines = preview.map { SpotTokens.attachmentValueLines(of: $0.text) } ?? 0
    }
}
