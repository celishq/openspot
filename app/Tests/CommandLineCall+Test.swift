import Foundation
@testable import OpenspotCore

extension CommandLineCall {
    init?(arguments: [String], environment: [String: String], reason: String? = nil) {
        self.init(arguments: arguments, spot: environment[CallWords.spotVariable], reason: reason)
    }
}
