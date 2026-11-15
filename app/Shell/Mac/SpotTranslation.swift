import Foundation
import NaturalLanguage
import OpenspotCore
import Translation

struct SpotTranslation: MacTranslation {
    static let capability = Capability(name: "translate")
    private static let fallback = "en"
    private static let languagesAsk = "languages"

    func translate(_ text: String, from: String?, to: String?) async throws -> TranslatedText {
        let pairs = [("from", from), ("to", to), ("text", text)]
        let request = TextBlock(fields: pairs.compactMap { key, value in value.map { .init(key: key, value: $0) } })
        return TranslatedText(block: try await Self.ask(request))
    }

    func languages() async throws -> [String] {
        try await Self.ask(TextBlock(fields: [.init(key: "do", value: Self.languagesAsk)])).values("language")
    }

    private static func ask(_ request: TextBlock) async throws -> TextBlock {
        try await SpotBlocking.run {
            let answer = String(decoding: try capability.call(Data(request.text.utf8)), as: UTF8.self)
            return TextBlock.blocks(in: answer).first ?? TextBlock(fields: [])
        }
    }

    static func serve() -> Never {
        capability.serve { request in
            let block = TextBlock.blocks(in: String(decoding: request, as: UTF8.self)).first ?? TextBlock(fields: [])
            if block.value("do") == languagesAsk {
                let codes = await LanguageAvailability().supportedLanguages.map(\.minimalIdentifier)
                return Data(TextBlock(fields: codes.map { .init(key: "language", value: $0) }).text.utf8)
            }
            let answer = try? await answer(to: block.value("text") ?? "", from: block.value("from"), to: block.value("to"))
            return Data((answer ?? TranslatedText(status: .failed)).block.text.utf8)
        }
    }

    private static func answer(to text: String, from: String?, to: String?) async throws -> TranslatedText {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return TranslatedText() }
        guard let code = from ?? NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue else {
            return TranslatedText(status: .unknown)
        }
        let target = to ?? TranslationTargets(preferred: Locale.preferredLanguages, source: base(of: code)).codes.first ?? fallback
        guard base(of: code) != base(of: target) else { return TranslatedText(text: text, from: code, to: target) }
        let source = Locale.Language(identifier: code)
        let output = Locale.Language(identifier: target)
        switch await LanguageAvailability().status(from: source, to: output) {
        case .installed: return TranslatedText(text: try await translation(of: text, from: source, to: output), from: code, to: target)
        case .supported: return TranslatedText(status: .missing, from: code, to: target)
        default: return TranslatedText(status: .unsupported, from: code, to: target)
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

    private static func base(of code: String) -> String {
        String(code.prefix { $0 != "-" && $0 != "_" })
    }
}
