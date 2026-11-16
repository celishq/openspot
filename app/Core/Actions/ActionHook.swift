import Foundation

public enum ActionHook: String, CaseIterable, Sendable {
    case when
    case hotkey

    var example: String {
        switch self {
        case .when: "hasIcon"
        case .hotkey: "openKey"
        }
    }
}
