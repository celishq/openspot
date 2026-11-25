import Foundation

public enum StorePlace: Hashable, Sendable {
    case mine
    case source(URL)
}
