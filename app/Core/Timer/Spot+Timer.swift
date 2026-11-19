import Foundation

extension Spot {
    var calls: [String] {
        self.uses.contains(.timer) ? FrameCheck.calls + [SpotTimer.call] : FrameCheck.calls
    }
}
