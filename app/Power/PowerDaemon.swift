import Foundation
import Security

struct PowerDaemon {
    private static let suffix = ".power"

    let app: String
    let team: String

    var label: String { app + Self.suffix }
    var plist: String { label + ".plist" }
    var appRequirement: String { requirement(of: app) }
    var helperRequirement: String { requirement(of: label) }

    static func readForApp() -> PowerDaemon? {
        guard let app = Bundle.main.bundleIdentifier, let team = signedTeam() else { return nil }
        return PowerDaemon(app: app, team: team)
    }

    static func readForHelper() -> PowerDaemon? {
        guard let label = Bundle.main.bundleIdentifier, label.hasSuffix(suffix), let team = signedTeam() else { return nil }
        return PowerDaemon(app: String(label.dropLast(suffix.count)), team: team)
    }

    private static func signedTeam() -> String? {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var information: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess else { return nil }
        return (information as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
    }

    private func requirement(of identifier: String) -> String {
        "anchor apple generic and identifier \"\(identifier)\" and certificate leaf[subject.OU] = \"\(team)\""
    }
}
