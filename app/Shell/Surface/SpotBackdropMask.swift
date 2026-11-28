import CoreGraphics
import Foundation
import OpenspotCore

final class SpotBackdropMask {
    private static let keptLimit = 2
    private var kept: [(fade: SpotBackdropFade, image: CGImage?)] = []
    private var reference: (fade: SpotBackdropFade, picture: CGContext)?
    private var moved: (slices: BackdropFade.Slices, image: CGImage)?

    func image(of fade: SpotBackdropFade, isMoving: Bool) -> CGImage? {
        if let shown = kept.first(where: { $0.fade == fade }) { return shown.image }
        if isMoving { return built(to: fade) ?? fade.image() }
        let image = fade.image()
        kept = Array((kept + [(fade, image)]).suffix(Self.keptLimit))
        trim()
        return image
    }

    private var bytes: Int {
        let drawn = reference.map { $0.picture.bytesPerRow * $0.picture.height } ?? 0
        return kept.reduce(drawn) { $0 + ($1.image.map { $0.bytesPerRow * $0.height } ?? 0) }
    }

    private func trim() {
        while bytes > SpotTokens.backdropMaskBytes, !kept.isEmpty { kept.removeFirst() }
        if bytes > SpotTokens.backdropMaskBytes {
            reference = nil
            moved = nil
        }
    }

    private func built(to fade: SpotBackdropFade) -> CGImage? {
        guard let area = fade.area else { return nil }
        if let reference, reference.fade.fade == fade.fade, reference.fade.size == fade.size, let drawn = reference.fade.area,
           let slices = fade.fade.slices(from: drawn, to: area, size: fade.size, scale: SpotTokens.backdropMaskScale) {
            if let moved, moved.slices == slices { return moved.image }
            guard let image = BackdropFade.image(of: reference.picture, slices: slices) else { return nil }
            moved = (slices, image)
            return image
        }
        guard let picture = fade.drawn() else { return nil }
        reference = (fade, picture)
        moved = nil
        trim()
        return picture.makeImage()
    }
}
