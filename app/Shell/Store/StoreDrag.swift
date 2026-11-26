import AppKit
import Observation
import OpenspotCore
import SwiftUI

@MainActor
@Observable
final class StoreDrag {
    private(set) var carry: StoreCarry?
    private(set) var isOverTarget = false
    @ObservationIgnored private var target: CGRect?

    static var pointer: CGPoint? {
        guard let event = NSApp.currentEvent, let view = event.window?.contentView else { return nil }
        return CGPoint(x: event.locationInWindow.x, y: view.bounds.height - event.locationInWindow.y)
    }

    func take(target next: CGRect) {
        target = next
    }

    func move(_ card: StoreCard, to point: CGPoint, grab: CGPoint) {
        if carry?.id != card.id {
            carry = StoreCarry(id: card.id, size: card.preview.size, point: point, grab: grab)
        } else {
            carry?.move(to: point)
        }
        let isOver = carry?.lands(on: target) == true
        if isOver != isOverTarget { isOverTarget = isOver }
    }

    func drop(_ store: Store) {
        guard let carry else { return }
        if carry.lands(on: target) { Task { await store.install(carry.id) } }
        withAnimation(SpotMotion.fade(isShown: false)) {
            self.carry = nil
            isOverTarget = false
        }
    }
}
