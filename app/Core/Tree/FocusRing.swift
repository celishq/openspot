import Foundation

public struct FocusRing: Equatable, Sendable {
    public let edge: SurfaceEdge
    public let outset: CGSize
    public let hugsControl: Bool

    public init(edge: SurfaceEdge, outset: CGSize, hugsControl: Bool = false) {
        self.edge = edge
        self.outset = outset
        self.hugsControl = hugsControl
    }

    public init(part: SpotPart, look: SpotPart.Look?, hasLabel: Bool = false, surface: SurfaceEdge) {
        let gap = SpotTokens.focusGap
        let around = CGSize(width: gap, height: gap)
        let box = FocusRing(edge: surface.inner(by: SpotTokens.padding - gap), outset: around)
        let row = FocusRing(edge: surface.inner(), outset: CGSize(width: SpotTokens.controlPadding, height: 0))
        if hasLabel || part.isEditable || look == .tile {
            self = box
        } else if case .round = part.press, look == .bare {
            self.init(edge: SurfaceEdge(radius: .infinity), outset: around, hugsControl: true)
        } else if part.press != .line {
            self = row
        } else {
            switch look {
            case .chip: self.init(edge: SurfaceEdge(radius: .infinity), outset: around, hugsControl: true)
            case .bare: self = row
            default: self = box
            }
        }
    }
}
