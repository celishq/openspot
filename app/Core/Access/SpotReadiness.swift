import Foundation

public enum SpotReadiness: String, Sendable {
    case ready, access, review, off

    init(isOn: Bool, needs: [MacAccess], refused: [SpotUse] = []) {
        self = !isOn ? .off : !refused.isEmpty ? .review : needs.isEmpty ? .ready : .access
    }

    init(_ spot: Spot, statuses: [MacAccess: ReadAccess], made: [String], refused: [SpotUse: Date]) {
        let needs = SpotAccess(spot, written: KeptCalls.shared.read(spot), made: made).missing(in: statuses)
        self.init(isOn: true, needs: needs, refused: SpotUse.allCases.filter { refused[$0] != nil && !spot.uses.contains($0) })
    }
}
