import Foundation

struct ReadRefusal: LocalizedError, Equatable {
    let reader: String

    var errorDescription: String? {
        "Openspot can't read \(reader). Allow it in the Attachments spot."
    }
}
