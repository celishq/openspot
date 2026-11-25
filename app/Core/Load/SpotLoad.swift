import CryptoKit
import Foundation

public struct SpotLoad: Sendable {
    enum Origin: Sendable {
        case own
        case core
        case app
    }

    struct Entry: Sendable {
        let id: String
        let file: URL
        let origin: Origin
        let spots: [Spot]?
        let refusal: String?
        let added: Date?

        func add(to result: inout ScanResult) {
            if let refusal { result.refused.append(ScanResult.Refusal(file: id, reason: refusal)) }
            guard let spots else { return }
            result.files.append(SpotFile(id: id, spots: spots))
        }

        func placed(_ spot: Spot) -> Spot {
            switch origin {
            case .app:
                return spot.builtIn()
            case .own, .core:
                var own = added.map(spot.added(at:)) ?? spot
                own.uses.remove(.account)
                return own
            }
        }
    }

    let entries: [Entry]
    let loose: [ScanResult.Refusal]
    let failure: String?
    public let stamp: [String: [Int]]
    let sources: [String: [String]]
    public let hasAppSpots: Bool

    public static let empty = SpotLoad(entries: [], loose: [], failure: nil, stamp: [:], sources: [:], hasAppSpots: false)

    public func result(hosted: [Spot] = []) throws -> ScanResult {
        if let failure { throw SpotError.fault(failure) }
        var result = ScanResult(files: hosted.isEmpty ? [] : [SpotFile(id: "openspot", spots: hosted)], refused: loose)
        let ownIDs = ownIDs
        for entry in entries where entry.origin == .own {
            entry.add(to: &result)
        }
        for entry in entries where entry.origin == .core && !ownIDs.contains(entry.id) {
            entry.add(to: &result)
        }
        for entry in entries where entry.origin == .app {
            entry.add(to: &result)
        }
        result.checkBoundEvents(also: entries.flatMap { $0.spots ?? [] })
        return result
    }

    var ownIDs: Set<String> {
        Set(entries.filter { $0.origin == .own }.map(\.id))
    }

    var coreIDs: Set<String> {
        Set(entries.filter { $0.origin == .core }.map(\.id)).subtracting(ownIDs)
    }

    public var coreChoices: [Spot] {
        let files = entries.filter { $0.origin == .core }.compactMap { entry in entry.spots.map { SpotFile(id: entry.id, spots: $0) } }
        return ScanResult(files: files, refused: []).spots.filter { $0.triggers.every == nil }
    }

    static func version(of stamp: [Int]) -> String {
        let bytes = stamp.flatMap { withUnsafeBytes(of: Int64($0).littleEndian, Array.init) }
        return SHA256.hash(data: bytes).prefix(4).map { String(format: "%02x", $0) }.joined()
    }

    public func stamp(of spot: Spot) -> [Int]? {
        guard let own = stamp[spot.url.path] else { return nil }
        let toml = spot.url.deletingLastPathComponent().appendingPathComponent(Manifest.fileName).path
        return ([toml] + (sources[spot.url.path] ?? [])).reduce(own) { $0 + (stamp[$1] ?? []) }
    }

    public func faultSpots(of scan: ScanResult, prompt: AgentPrompt) -> [Spot] {
        let loaded = Set(scan.files.filter { !$0.spots.isEmpty }.map(\.id))
        let faults = Dictionary(grouping: scan.refused.filter { !loaded.contains($0.file) }, by: \.file)
        return faults.keys.sorted().compactMap { id in
            guard let entry = entries.first(where: { $0.origin == .own && $0.id == id }) else { return nil }
            let name = SpotFile.name(of: entry.file)
            let spot = Spot(
                id: id,
                name: "Fix",
                url: entry.file,
                kind: .list,
                symbol: "exclamationmark.triangle",
                subtitle: name,
                triggers: .sheet,
                host: .fault(FaultSpot(file: entry.file, name: name, faults: faults[id]?.map(\.reason) ?? [], prompt: prompt))
            )
            return entry.added.map(spot.added(at:)) ?? spot
        }
    }
}
