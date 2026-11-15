import Foundation
import NaturalLanguage
import OpenspotCore
import Translation

enum SpotTranslation {
    private static let fallback = "en"

    static func languages() async -> String {
        let preferred = TranslationTargets(preferred: Locale.preferredLanguages, source: "").codes
        let found = await LanguageAvailability().supportedLanguages
            .map { (code: $0.minimalIdentifier, name: Locale.current.localizedString(forIdentifier: $0.minimalIdentifier) ?? $0.minimalIdentifier) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        let summary = TextBlock(fields: preferred.map { .init(key: "preferred", value: $0) })
        let blocks = found.map { TextBlock(fields: [.init(key: "language", value: $0.code), .init(key: "name", value: $0.name)]) }
        return ([summary] + blocks).map(\.text).joined(separator: "\n")
    }

    static let capability = Capability(name: "translate")

    static func call(text: String, from: String?, to: String?) throws -> String {
        let pairs = [("from", from), ("to", to), ("text", text)]
        let request = TextBlock(fields: pairs.compactMap { key, value in value.map { .init(key: key, value: $0) } }).text
        return String(decoding: try capability.call(Data(request.utf8)), as: UTF8.self)
    }

    static func serve() -> Never {
        capability.serve { request in
            let block = TextBlock.blocks(in: String(decoding: request, as: UTF8.self)).first ?? TextBlock(fields: [])
            let answer = try? await answer(to: block.value("text") ?? "", from: block.value("from"), to: block.value("to"))
            return Data((answer ?? reply(status: "failed")).utf8)
        }
    }

    private static func answer(to text: String, from: String?, to: String?) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        guard let code = from ?? NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue else {
            return reply(status: "unknown")
        }
        let target = to ?? TranslationTargets(preferred: Locale.preferredLanguages, source: base(of: code)).codes.first ?? fallback
        guard base(of: code) != base(of: target) else { return reply(text: text, from: code, to: target) }
        let source = Locale.Language(identifier: code)
        let output = Locale.Language(identifier: target)
        switch await LanguageAvailability().status(from: source, to: output) {
        case .installed: return reply(text: try await translation(of: text, from: source, to: output), from: code, to: target)
        case .supported: return reply(status: "missing", from: code, to: target)
        default: return reply(status: "unsupported", from: code, to: target)
        }
    }

    @MainActor private static var sessions: [String: TranslationSession] = [:]

    @MainActor
    private static func translation(of text: String, from: Locale.Language, to: Locale.Language) async throws -> String {
        let pair = "\(from.minimalIdentifier)>\(to.minimalIdentifier)"
        nonisolated(unsafe) let session = sessions[pair] ?? makeSession(from: from, to: to)
        sessions[pair] = session
        return try await session.translate(text).targetText
    }

    @MainActor
    private static func makeSession(from: Locale.Language, to: Locale.Language) -> TranslationSession {
        if #available(macOS 26.4, *) {
            return TranslationSession(installedSource: from, target: to, preferredStrategy: .highFidelity)
        }
        return TranslationSession(installedSource: from, target: to)
    }

    private static func reply(text: String? = nil, status: String? = nil, from: String? = nil, to: String? = nil) -> String {
        let pairs = [("text", text), ("status", status), ("from", from), ("to", to)]
        return TextBlock(fields: pairs.compactMap { key, value in value.map { .init(key: key, value: $0) } }).text
    }

    private static func base(of code: String) -> String {
        String(code.prefix { $0 != "-" && $0 != "_" })
    }
}
