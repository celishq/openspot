import Foundation

extension ReadSources {
    static let rule = CallRule(use: .read, used: "read what the person works on", flags: .needsApp)

    static func work(in context: CallContext, asks: Bool? = nil, _ read: @escaping @Sendable (ReadSources, Bool) async throws -> [TextBlock]) -> CommandAPI.Work {
        let reads = context.mac.reads
        let asks = asks ?? !context.isInShow
        let runs = context.runs
        let caller = context.request.caller
        return CommandAnswer.work {
            let sources = try Mac.part(reads, "reads")
            do {
                return try await read(sources, asks).map(\.text).joined(separator: "\n")
            } catch let refusal as ReadRefusal {
                if let runs, let caller { _ = await runs.take(SpotEffect.attachment(.denied(refusal.reader)), from: caller) }
                throw refusal
            }
        }
    }
}
