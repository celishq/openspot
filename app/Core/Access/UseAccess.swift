import Foundation

public struct UseAccess: Equatable, Sendable {
    public let needs: Set<MacAccess>
    public let optional: Set<MacAccess>

    public static let all = Self.all(in: CommandNoun.all)

    static func all(in nouns: [CommandNoun]) -> [SpotUse: UseAccess] {
        let rules = nouns.flatMap(\.verbs).compactMap { verb in verb.rule.use.map { ($0, verb.rule) } }
        return Dictionary(grouping: rules, by: \.0).compactMapValues { found in
            let rules = found.map(\.1)
            let needs = rules.map(\.needs).reduce(Set(MacAccess.allCases)) { $0.intersection($1) }
            let any = rules.reduce(Set<MacAccess>()) { $0.union($1.needs).union($1.mayNeed) }
            return any.isEmpty ? nil : UseAccess(needs: needs, optional: any.subtracting(needs))
        }
    }

    static func needs(of uses: Set<SpotUse>) -> Set<MacAccess> {
        uses.reduce([]) { $0.union(all[$1]?.needs ?? []) }
    }
}
