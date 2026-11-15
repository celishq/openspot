import Foundation

public protocol MacTranslation: Sendable {
    func translate(_ text: String, from: String?, to: String?) async throws -> TranslatedText
    func languages() async throws -> [String]
}
