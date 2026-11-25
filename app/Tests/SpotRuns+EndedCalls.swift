@testable import OpenspotCore

extension SpotRuns {
    func endedCalls() -> () -> Int {
        var count = 0
        let earlier = onCall
        onCall = { record in
            earlier?(record)
            count += 1
        }
        return { count }
    }
}
