import Foundation

public enum StoreButton: Equatable, Sendable {
    case install, installed, update, edited, locked

    init(of own: SpotCatalog.Item?) {
        guard let own else {
            self = .install
            return
        }
        if own.origin == .core {
            self = .locked
            return
        }
        switch own.copy {
        case .update: self = .update
        case .edited: self = .edited
        case .current, nil: self = .installed
        }
    }
}
