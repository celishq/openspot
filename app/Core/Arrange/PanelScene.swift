import Foundation

public struct PanelScene: Equatable, Sendable {
    public let isArranging: Bool
    public let search: String?
    public let swap: String?
    public let isHeld: Bool
    public let picks: Bool

    public init(isArranging: Bool = false, search: String? = nil, swap: String? = nil, isHeld: Bool = false, picks: Bool = false) {
        self.isArranging = isArranging
        self.search = search
        self.swap = swap
        self.isHeld = isHeld
        self.picks = picks
    }
}
