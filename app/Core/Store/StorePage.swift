import Foundation

public struct StorePage: Equatable, Sendable {
    public let id: String
    public let spot: Spot
    public let from: String
    public let updated: String?
    public let readme: [String]
    public let shown: [StoreReadmeLine]
    public let trust: [ReviewLine]
    public let button: StoreButton
    public let hasSample: Bool
    public let runsSample: Bool
    public let preview: StorePreview?
}
