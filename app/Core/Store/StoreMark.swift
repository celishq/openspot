import Foundation

public enum StoreMark: String, Sendable {
    case installed, core, edited, update

    init?(of item: SpotCatalog.Item) {
        if item.origin == .core {
            self = .core
            return
        }
        switch item.copy {
        case .edited: self = .edited
        case .update: self = .update
        case .current, nil: return nil
        }
    }
}
