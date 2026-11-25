import Foundation
@testable import OpenspotCore

extension Spot {
    func takes(paths: [String]) -> Bool {
        takes(AttachmentValue(files: FileKinds.Disk().read(paths)))
    }
}
