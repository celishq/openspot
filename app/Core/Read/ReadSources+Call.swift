import Foundation

extension ReadSources {
    static let rule = CallRule(use: .read, used: "read what the person works on", flags: .needsApp)
    static let browserRule = CallRule(use: .read, used: rule.used, flags: rule.flags, needs: [.automation])
    static let selectionRule = CallRule(use: .read, used: rule.used, flags: rule.flags, mayNeed: [.accessibility, .automation])

    static func work(in context: CallContext, asks: Bool? = nil, _ read: @escaping @Sendable (ReadSources, Bool) async throws -> [TextBlock]) -> CommandAPI.Work {
        let reads = context.mac.reads
        let asks = asks ?? !context.isInShow
        return CommandAnswer.work {
            let sources = ReadSources(mac: try Mac.part(reads, "reads"))
            return try await read(sources, asks).map(\.text).joined(separator: "\n")
        }
    }
}
