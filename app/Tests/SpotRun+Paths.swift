import Foundation
@testable import OpenspotCore

@MainActor
extension SpotRun {
    @discardableResult
    func drop(paths: [String]) -> Bool {
        drop(ContextValue(files: FileKinds.Disk().read(paths)))
    }
}
