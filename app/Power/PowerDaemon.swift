import Foundation

enum PowerDaemon {
    static let label = "openspot.celis.ai.power"
    static let plist = label + ".plist"
    static let team = "NNK86LQK58"
    static let app = requirement(of: "openspot.celis.ai")
    static let helper = requirement(of: label)

    static func requirement(of identifier: String) -> String {
        "anchor apple generic and identifier \"\(identifier)\" and certificate leaf[subject.OU] = \"\(team)\""
    }
}
