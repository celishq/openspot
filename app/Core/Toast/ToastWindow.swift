import CoreGraphics
import Foundation

@MainActor
public protocol ToastWindow: AnyObject {
    func measure(_ toast: Toast) -> CGSize
    func place()
    func bringToFront()
    func putAway()
    func nextFrame(_ body: @escaping @MainActor () -> Void)
    func move(_ body: () -> Void)
    func holdFixKey(_ key: Shortcut, press: @escaping @MainActor @Sendable () -> Void) -> Bool
    func dropFixKey()
}
