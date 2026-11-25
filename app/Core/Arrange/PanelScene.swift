import Foundation

public struct PanelScene: Equatable, Sendable {
    public let isArranging: Bool
    public let search: String?
    public let swap: String?

    public init(isArranging: Bool = false, search: String? = nil, swap: String? = nil) {
        self.isArranging = isArranging
        self.search = search
        self.swap = swap
    }
}
