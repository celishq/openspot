@testable import OpenspotCore

extension SpotRuns {
    func endedCalls() -> () -> Int {
        var count = 0
        onCall = { _ in count += 1 }
        return { count }
    }
}
