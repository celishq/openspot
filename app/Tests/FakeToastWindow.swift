import CoreGraphics
import Foundation
@testable import OpenspotCore

@MainActor
final class FakeToastWindow: ToastWindow {
    var fronts = 0
    var putAways = 0
    var fixPress: (@MainActor @Sendable () -> Void)?

    func measure(_ toast: Toast) -> CGSize {
        return CGSize(width: 100 + CGFloat(toast.words.count), height: 40)
    }

    var reached: [CGFloat] = []

    func reach(_ height: CGFloat) {
        reached.append(height)
    }

    func shift(for width: CGFloat) -> CGFloat {
        0
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
        fixPress = press
        return true
    }

    func move(_ body: () -> Void) {
        body()
    }

    func dropFixKey() {
        fixPress = nil
    }
}
