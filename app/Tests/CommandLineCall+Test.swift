import Foundation
@testable import OpenspotCore

extension CommandLineCall {
    init?(arguments: [String], environment: [String: String]) {
        self.init(arguments: arguments, spot: environment[CallWords.spotVariable], reason: environment[CallWords.reasonVariable])
    }
}
