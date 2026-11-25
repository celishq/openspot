import Foundation

struct SpotAccess {
    let needs: Set<MacAccess>
    let maybe: Set<MacAccess>
    let byUse: [SpotUse: (needs: Set<MacAccess>, maybe: Set<MacAccess>)]

    init(_ spot: Spot, written: [[String]], made: [String]) {
        let rules = (written + made.map { $0.split(separator: " ").map(String.init) }).compactMap { CommandLineCall.looseRule(of: $0, spot: spot.id)?.rule }
        needs = rules.reduce(Set<MacAccess>()) { $0.union($1.needs) }
        maybe = rules.reduce(Set<MacAccess>()) { $0.union($1.mayNeed) }.subtracting(needs)
        var byUse: [SpotUse: (needs: Set<MacAccess>, maybe: Set<MacAccess>)] = [:]
        for rule in rules {
            guard let use = rule.use, !rule.needs.isEmpty || !rule.mayNeed.isEmpty else { continue }
            let kept = byUse[use] ?? ([], [])
            byUse[use] = (kept.needs.union(rule.needs), kept.maybe.union(rule.mayNeed))
        }
        self.byUse = byUse.mapValues { ($0.needs, $0.maybe.subtracting($0.needs)) }
    }

    func missing(in statuses: [MacAccess: ReadAccess]) -> [MacAccess] {
        MacAccess.allCases.filter { needs.contains($0) && [.denied, .unasked].contains(statuses[$0] ?? .unknown) }
    }
}
