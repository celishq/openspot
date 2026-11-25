import Foundation

public enum SpotReadiness: String, Sendable {
    case ready, access, review, off

    init(isOn: Bool, needs: [MacAccess]) {
        self = !isOn ? .off : needs.isEmpty ? .ready : .access
    }
}
