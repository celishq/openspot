import Foundation

public enum SpotReadiness: String, Sendable {
    case ready, access, review, off

    init(isOn: Bool, needs: [MacAccess], refused: [SpotUse] = []) {
        self = !isOn ? .off : !refused.isEmpty ? .review : needs.isEmpty ? .ready : .access
    }
}
