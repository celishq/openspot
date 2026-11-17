import Foundation

extension SpotRuns {
    public convenience init(showing frames: [String: String]) {
        self.init()
        standIn = { ShownLink(frame: frames[$0.id]) }
    }

    public var shownFrames: [String: String] {
        sheets.compactMapValues(\.shownFrame)
    }
}
