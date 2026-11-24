import Foundation

public struct SheetMotion: Equatable, Sendable {
    public let morph: SheetMorph?
    public var progress: Double

    public init(morph: SheetMorph?, progress: Double) {
        self.morph = morph
        self.progress = progress
    }

    public func place(of foot: PanelFoot) -> CGFloat {
        guard let morph else { return progress < 1 ? foot.closed : foot.open }
        return max(morph.foot(at: progress) - morph.foot(at: 1) + foot.open, foot.path(at: progress))
    }
}
