import Foundation

extension Spot {
    var reservedCalls: [String] {
        self.uses.contains(.timer) ? FrameCheck.calls + [SpotTimer.call] : FrameCheck.calls
    }
}
