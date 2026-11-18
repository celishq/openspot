import Foundation

enum ScriptKind: Equatable {
    case settings(SpotSettings)
    case host(HostSheet)
    case inline
    case stay
    case once

    init(of spot: Spot) {
        if spot.holdsSettings, let settings = spot.settingsSheet {
            self = .settings(settings)
        } else if let host = spot.host {
            self = .host(host)
        } else {
            switch spot.mode {
            case .inline: self = .inline
            case .stay: self = .stay
            case .once: self = .once
            }
        }
    }

    var keepsState: Bool {
        self == .stay
    }

    var answersInApp: Bool {
        switch self {
        case .settings, .host: true
        case .inline, .stay, .once: false
        }
    }
}
