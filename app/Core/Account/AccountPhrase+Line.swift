import Foundation

extension AccountPhrase {
    public func line(isSignedIn: Bool) -> [String: String] {
        let finished = typed.dropLast(text.last?.isWhitespace == true ? 0 : 1)
        if let problem { return ["title": problem, "icon": "exclamationmark.triangle", "tone": "bad"] }
        if let account {
            return isSignedIn
                ? ["title": "Replaces the account on this Mac", "icon": "exclamationmark.triangle", "tone": "warn", "detail": AccountKey.short(account)]
                : ["title": "Signs in as", "icon": "checkmark.circle", "tone": "good", "detail": AccountKey.short(account)]
        }
        if let unknown = finished.first(where: { !$0.isKnown }) { return ["title": "\(unknown.text) isn't an account word", "icon": "exclamationmark.triangle", "tone": "bad"] }
        if let completion { return ["title": "Did you mean \(completion)?", "icon": "questionmark.circle"] }
        return text.isEmpty ? [:] : ["title": counter]
    }
}
