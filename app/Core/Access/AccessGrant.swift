import Foundation

public struct AccessGrant: Equatable, Sendable {
    public let spot: String
    public let steps: [MacAccess]
    public private(set) var done: Set<MacAccess> = []

    public init(spot: String, steps: [MacAccess]) {
        self.spot = spot
        self.steps = steps.filter { !$0.needsRestart } + steps.filter(\.needsRestart)
    }

    init?(kept: [String]) {
        guard let spot = kept.first else { return nil }
        let steps = kept.dropFirst().compactMap(MacAccess.init(rawValue:))
        guard !steps.isEmpty else { return nil }
        self.init(spot: spot, steps: steps)
    }

    public var step: MacAccess? {
        steps.first { !done.contains($0) }
    }

    var kept: [String] {
        [spot] + steps.map(\.rawValue)
    }

    public mutating func take(_ statuses: [MacAccess: ReadAccess]) {
        done.formUnion(steps.filter { statuses[$0] == .allowed })
    }

    var block: TextBlock {
        let listed = { (steps: [MacAccess]) in steps.isEmpty ? nil : steps.map(\.rawValue).joined(separator: ",") }
        let fields: [(String, String?)] = [
            ("item", "grant"), ("spot", spot), ("steps", listed(steps)), ("step", step?.rawValue),
            ("done", listed(steps.filter(done.contains))), ("place", step?.place), ("restart", step?.needsRestart == true ? "true" : nil)
        ]
        return TextBlock(fields: fields.compactMap { key, value in value.map { TextBlock.Field(key: key, value: $0) } })
    }
}
