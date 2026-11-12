import Foundation

/// The account flow as a sheet of the panel, which grows out of the search field. The app draws its steps in the place of
/// its `view` block, and its buttons are blocks, so they take keys as any sheet's buttons do. The words never leave the app.
@MainActor
public final class AccountSheet: Sendable, Equatable {
    public static let id = "openspot/account-sheet"
    public static let name = "Account"
    public static let symbol = "person.crop.circle"
    /// The id of the block whose place the app draws the steps in.
    public static let viewPart = "account"

    public let flow: AccountFlow
    /// Asks for Touch ID or the Mac password, and returns whether the person passed.
    private let allows: @MainActor (String) async -> Bool
    /// Ends the sheet, once its flow is done or the person leaves it.
    private let finished: @MainActor () -> Void

    public init(flow: AccountFlow, allows: @escaping @MainActor (String) async -> Bool = { _ in true }, finished: @escaping @MainActor () -> Void) {
        self.flow = flow
        self.allows = allows
        self.finished = finished
    }

    nonisolated deinit {}

    public nonisolated static func == (lhs: AccountSheet, rhs: AccountSheet) -> Bool {
        lhs === rhs
    }

    /// Its sheet, which grows out of the search field.
    public var spot: Spot {
        Spot(id: Self.id, name: Self.name, url: URL(fileURLWithPath: "/"), kind: .list, symbol: Self.symbol, read: .sheet, order: .max, host: .account(self), growsFromField: true)
    }

    /// One button of a step: its id, its words, and whether it is the main one, which ⌘↩ presses.
    struct Button: Equatable {
        let id: String
        let title: String
        var isMain = false
        var shortcut: String?
    }

    /// The buttons of the step that shows.
    var buttons: [Button] {
        switch flow.step {
        case .choose: [Button(id: "sign-in", title: "Use existing account"), Button(id: "create", title: "Create account", isMain: true)]
        case .about: [Button(id: "show", title: "Show my words", isMain: true)]
        case .account: [Button(id: "close", title: "Done", isMain: true), Button(id: "show", title: "Show my words"), Button(id: "leave", title: "Sign out…")]
        case .words: [Button(id: "close", title: flow.isBackedUp ? "Done" : "Later"), Button(id: "wrote", title: "I wrote them down", isMain: true)]
        case .check: [Button(id: "again", title: "Show the words again")]
        case .restore: [Button(id: "nsec", title: flow.usesNsec ? "Use your 12 words" : "Use an nsec instead"), Button(id: "sign-in", title: "Sign in", isMain: true)]
        case .signOut: [Button(id: "close", title: "Cancel", shortcut: "escape"), Button(id: "sign-out", title: "Sign out", isMain: true)]
        case .done: []
        }
    }

    /// Answers one call with the text a script would print: the sheet for `read`, and nothing after a press, so that the
    /// sheet reads again. The words of a key that the Mac held before, and a sign-out, first ask for Touch ID.
    public func answer(_ arguments: [String]) async throws -> String {
        switch arguments.first {
        case "read": return sheet
        case "create": flow.create()
        case "show":
            if flow.hadKey, !(await allows("show your account words")) { return "" }
            flow.showWords()
        case "leave": flow.start(.signOut)
        case "wrote": flow.wroteThemDown()
        case "again": flow.showWordsAgain()
        case "sign-in" where flow.step == .restore: flow.signIn()
        case "sign-in": flow.start(.restore)
        case "nsec":
            flow.usesNsec.toggle()
            flow.phrase = ""
        case "sign-out":
            guard await allows("sign out of your account") else { return "" }
            flow.signOut()
        case "close": finished()
        default: throw SpotError.failed(1, "This sheet cannot do that.")
        }
        if flow.step == .done { finished() }
        return ""
    }

    private var sheet: String {
        let buttons = buttons
        let line = (buttons.count == 1 ? ["."] : []) + buttons.map(\.id)
        var head = [TextBlock.Field(key: "grid", value: Array(repeating: Self.viewPart, count: max(line.count, 1)).joined(separator: " "))]
        if !buttons.isEmpty {
            head.append(.init(key: "grid", value: line.joined(separator: " ")))
        }
        let blocks = [TextBlock(fields: head), TextBlock(fields: [.init(key: "view", value: Self.viewPart)])] + buttons.map { button in
            var fields: [TextBlock.Field] = [.init(key: "button", value: button.id), .init(key: "title", value: button.title)]
            if button.isMain {
                fields += [.init(key: "shortcut", value: "cmd+return"), .init(key: "look", value: "strong")]
            } else if let shortcut = button.shortcut {
                fields.append(.init(key: "shortcut", value: shortcut))
            }
            return TextBlock(fields: fields)
        }
        return blocks.map(\.text).joined(separator: "\n")
    }
}
