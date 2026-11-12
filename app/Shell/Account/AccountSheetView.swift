import OpenspotCore
import SwiftUI

/// The steps of the account sheet, drawn in the place of its `view` block. Its buttons are the sheet's own blocks; this
/// view draws the words, the check and the sign-in field, which no block can.
struct AccountSheetView: View {
    @Bindable var flow: AccountFlow
    @FocusState private var isTyping: Bool

    private static let gap: CGFloat = 10
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 6, alignment: .leading), count: 2)
    private static let chipRadius: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            step
            if let failure = flow.failure {
                Text(failure).font(SpotType.detail).foregroundStyle(.red)
            }
            Spacer(minLength: 0)
        }
        .font(SpotType.body)
        .foregroundStyle(SpotTheme.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var step: some View {
        switch flow.step {
        case .choose: choose
        case .about: about
        case .words: words
        case .check: check
        case .restore: restore
        case .account: account
        case .signOut: signOut
        case .done: EmptyView()
        }
    }

    private var choose: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            heading("Set up your account")
            Text("Openspot signs what you publish with your account, so people can tell that an update comes from you.")
                .modifier(SpotSecondaryText())
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            heading("Your account is 12 words")
            point("key", "They are your account. There's no email, no password and no server.")
            point("eye.slash", "Anyone who has them can publish as you, so keep them private.")
            point("exclamationmark.triangle", "Openspot can't reset them. If you lose them and this Mac, the account is gone.")
        }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            heading("Write down your words")
            Text("On paper, in this order.").modifier(SpotSecondaryText())
            LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 6) {
                ForEach(Array(flow.words.enumerated()), id: \.offset) { index, word in
                    chip(index + 1, word, isKnown: true)
                }
            }
        }
    }

    private var check: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            heading("Check your words")
            ForEach(Array(flow.checks.enumerated()), id: \.offset) { index, check in
                VStack(alignment: .leading, spacing: 6) {
                    Text("Word \(check.position)").modifier(SpotSecondaryText())
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
                        ForEach(check.choices, id: \.self) { word in
                            Button { flow.pick(word, at: index) } label: {
                                Text(word)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(fill(isOn: check.picked == word), in: RoundedRectangle(cornerRadius: Self.chipRadius, style: .continuous))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            if let mistake = flow.mistake {
                Text(mistake).font(SpotType.detail).foregroundStyle(.red)
            }
        }
    }

    private var restore: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            heading(flow.usesNsec ? "Sign in with your nsec" : "Sign in with your words")
            TextField(flow.usesNsec ? "nsec1…" : "Type or paste your 12 words", text: $flow.phrase, axis: .vertical)
                .textFieldStyle(.plain)
                .font(SpotType.input)
                .lineLimit(2...4)
                .focused($isTyping)
                .padding(8)
                .background(SpotTheme.ink.opacity(SpotTheme.fill), in: RoundedRectangle(cornerRadius: Self.chipRadius, style: .continuous))
                .onKeyPress(.tab) {
                    guard flow.completion != nil else { return .ignored }
                    flow.complete()
                    return .handled
                }
                .onAppear { isTyping = true }
            if !flow.typed.isEmpty {
                LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 6) {
                    ForEach(Array(flow.typed.enumerated()), id: \.offset) { index, word in
                        chip(index + 1, word.text, isKnown: word.isKnown)
                    }
                }
            }
            status
            if let replacing = flow.replacing, flow.canSignIn {
                Text(replacing).font(SpotType.detail).foregroundStyle(.orange)
            }
        }
    }

    /// The line under the sign-in field: what is wrong, the account it signs in to, or how many words it has.
    @ViewBuilder private var status: some View {
        if let problem = flow.problem {
            Text(problem).font(SpotType.detail).foregroundStyle(.red)
        } else if let account = flow.account {
            Text("Signs in as \(String(account.prefix(12)))…\(String(account.suffix(6)))").font(SpotType.detail).foregroundStyle(.green)
        } else if let completion = flow.completion {
            Text("Tab: \(completion)").font(SpotType.detail).modifier(SpotSecondaryText())
        } else if !flow.usesNsec {
            Text(flow.counter).font(SpotType.detail).modifier(SpotSecondaryText())
        }
    }

    private var account: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            heading("Your account")
            Text("Openspot signs what you publish with it.").modifier(SpotSecondaryText())
            if let npub = flow.npub {
                Text("\(String(npub.prefix(12)))…\(String(npub.suffix(6)))").font(SpotType.body.monospaced()).textSelection(.enabled)
            }
            point(flow.isBackedUp ? "checkmark.shield" : "exclamationmark.triangle", flow.isBackedUp ? "Your 12 words are backed up." : "Your 12 words are not backed up yet.")
        }
    }

    private var signOut: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            heading("Sign out of your account?")
            Text(flow.signOutWords).modifier(SpotSecondaryText())
        }
    }

    private func heading(_ words: String) -> some View {
        Text(words).font(SpotType.value)
    }

    private func point(_ symbol: String, _ words: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).frame(width: 18).modifier(SpotSecondaryText())
            Text(words).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func chip(_ number: Int, _ word: String, isKnown: Bool) -> some View {
        HStack(spacing: 4) {
            Text("\(number)").font(SpotType.small).monospacedDigit().modifier(SpotSecondaryText())
            Text(word).foregroundStyle(isKnown ? SpotTheme.ink : .red).lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill(isOn: false), in: RoundedRectangle(cornerRadius: Self.chipRadius, style: .continuous))
    }

    private func fill(isOn: Bool) -> Color {
        isOn ? SpotTheme.accent.opacity(0.35) : SpotTheme.ink.opacity(SpotTheme.fill)
    }
}
