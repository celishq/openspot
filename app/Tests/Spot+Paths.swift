import Foundation
@testable import OpenspotCore

extension Spot {
    func takes(paths: [String]) -> Bool {
        takes(ContextValue(files: FileKinds.Disk().read(paths)))
    }
}
