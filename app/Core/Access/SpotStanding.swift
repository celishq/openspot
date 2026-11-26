import Foundation

public struct SpotStanding: Identifiable, Equatable, Sendable {
    public struct UseNeeds: Identifiable, Equatable, Sendable {
        public let id: SpotUse
        public let needs: [MacAccess]
        public let maybe: [MacAccess]

        public var needsLine: String? {
            let parts = [needs.isEmpty ? nil : "Needs \(MacAccess.names(needs))", maybe.isEmpty ? nil : "May ask for \(MacAccess.names(maybe))"].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
    }

    public let id: String
    public let spot: Spot
    public let readiness: SpotReadiness
    public let uses: [UseNeeds]
    public let missing: [MacAccess]
    public let refused: [SpotUse]
    let needs: Set<MacAccess>
    let maybe: Set<MacAccess>
    let byUse: [UseNeeds]
    let last: [SpotUse: Date]

    init(_ spot: Spot, id: String? = nil, written: [[String]], statuses: [MacAccess: AccessStatus], last: [String: Date], refused: [SpotUse: Date]) {
        let rules = Self.rules(of: spot, written: written, last: last)
        let ordered = { (set: Set<MacAccess>) in MacAccess.allCases.filter(set.contains) }
        needs = rules.reduce(Set<MacAccess>()) { $0.union($1.needs) }
        maybe = rules.reduce(Set<MacAccess>()) { $0.union($1.mayNeed) }.subtracting(needs)
        var found: [SpotUse: (needs: Set<MacAccess>, maybe: Set<MacAccess>)] = [:]
        for rule in rules {
            guard let use = rule.use, !rule.needs.isEmpty || !rule.mayNeed.isEmpty else { continue }
            let kept = found[use] ?? ([], [])
            found[use] = (kept.needs.union(rule.needs), kept.maybe.union(rule.mayNeed))
        }
        let byUse = found.map { use, accesses in UseNeeds(id: use, needs: ordered(accesses.needs), maybe: ordered(accesses.maybe.subtracting(accesses.needs))) }
        let declared = spot.uses.sorted { $0.rawValue < $1.rawValue }
        self.id = id ?? spot.id
        self.spot = spot
        self.byUse = byUse.sorted { $0.id.rawValue < $1.id.rawValue }
        uses = declared.map { use in byUse.first { $0.id == use } ?? UseNeeds(id: use, needs: [], maybe: []) }
        let missing = Self.missing(needs, statuses: statuses)
        let undeclared = Self.undeclared(by: spot, refused: refused)
        readiness = !undeclared.isEmpty ? .review : missing.isEmpty ? .ready : .access
        self.missing = missing
        self.refused = undeclared
        var times: [SpotUse: Date] = [:]
        for (call, date) in last {
            guard let use = CommandLineCall.looseRule(of: call.split(separator: " ").map(String.init), spot: spot.id)?.rule.use else { continue }
            times[use] = max(times[use] ?? date, date)
        }
        self.last = times
    }

    static func lacks(_ spot: Spot, written: [[String]], statuses: [MacAccess: AccessStatus], last: [String: Date], refused: [SpotUse: Date]) -> Bool {
        let needs = rules(of: spot, written: written, last: last).reduce(Set<MacAccess>()) { $0.union($1.needs) }
        return !undeclared(by: spot, refused: refused).isEmpty || !missing(needs, statuses: statuses).isEmpty
    }

    private static func rules(of spot: Spot, written: [[String]], last: [String: Date]) -> [CallRule] {
        (written + last.keys.map { $0.split(separator: " ").map(String.init) }).compactMap { CommandLineCall.looseRule(of: $0, spot: spot.id)?.rule }
    }

    private static func missing(_ needs: Set<MacAccess>, statuses: [MacAccess: AccessStatus]) -> [MacAccess] {
        MacAccess.allCases.filter { needs.contains($0) && [.denied, .unasked].contains(statuses[$0] ?? .unknown) }
    }

    private static func undeclared(by spot: Spot, refused: [SpotUse: Date]) -> [SpotUse] {
        SpotUse.allCases.filter { refused[$0] != nil && !spot.uses.contains($0) }
    }

    public var title: String {
        spot.name
    }

    public var detail: String {
        spot.subtitle ?? ""
    }

    public var lacks: Bool {
        readiness == .access || readiness == .review
    }

    public var lack: String {
        readiness == .review ? "Tried \(refused.map(\.rawValue).joined(separator: ", ")), which it doesn’t declare" : "Needs \(MacAccess.names(missing))"
    }

    public var banner: (title: String, line: String)? {
        switch readiness {
        case .review: ("\(title) needs your review", lack)
        case .access: ("\(title) can’t run yet", "It needs \(MacAccess.names(missing)) from macOS.")
        case .ready: nil
        }
    }
}
