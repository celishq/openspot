import Foundation

public struct CallWords: Sendable {
    static let spotWord = "--spot"
    public static let spotVariable = "OPENSPOT_ID"

    public let rest: [String]
    public let spot: String?
    public let reason: String?
    let fit: CommandForm.Words?

    init(rest: [String], spot: String?, reason: String?, form: CommandForm = CommandForm("")) {
        self.rest = rest
        self.spot = spot
        self.reason = reason
        fit = form.fit(rest)
    }

    var isInShow: Bool {
        reason != nil
    }

    var form: PrintForm? {
        fit.flatMap { $0.rest.isEmpty ? $0.form : nil }
    }

    var one: String? {
        rest.count == 1 ? rest[0] : nil
    }

    var none: Bool {
        rest.isEmpty
    }
}
