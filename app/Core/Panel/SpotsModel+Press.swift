import Foundation

extension SpotsModel {
    func asOnePress<T>(_ work: () -> T) -> T {
        pressDepth += 1
        defer {
            pressDepth -= 1
            if pressDepth == 0, hintIsStale { takeHint() }
            if pressDepth == 0, isPeeking { takePeek() }
            if pressDepth == 0 { pressCuts = false }
        }
        return work()
    }
}
