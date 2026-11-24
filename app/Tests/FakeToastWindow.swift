import CoreGraphics
import Foundation
@testable import OpenspotCore

@MainActor
final class FakeToastWindow: ToastWindow {
    var measures = 0
    var places = 0
    var fronts = 0
    var putAways = 0
    var heldKeys: [Shortcut] = []
    var fixPress: (@MainActor @Sendable () -> Void)?

    func measure(_ toast: Toast) -> CGSize {
        measures += 1
        return CGSize(width: 100 + CGFloat(toast.words.count), height: 40)
    }

    func place() {
        places += 1
    }

    func bringToFront() {
        fronts += 1
    }

    func putAway() {
        putAways += 1
    }

    func nextFrame(_ body: @escaping @MainActor () -> Void) {
        DispatchQueue.main.async(execute: body)
    }

    func holdFixKey(_ key: Shortcut, press: @escaping @MainActor @Sendable () -> Void) -> Bool {
        heldKeys.append(key)
        fixPress = press
        return true
    }

    func dropFixKey() {
        fixPress = nil
    }
}
