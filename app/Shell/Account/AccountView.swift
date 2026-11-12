import OpenspotCore
import SwiftUI

/// The steps of the account window, drawn from its flow. It closes once the flow is done.
struct AccountView: View {
    @Bindable var flow: AccountFlow
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            step
            if let failure = flow.failure {
                Text(failure).foregroundStyle(.red)
            }
        }
        .padding(24)
        .frame(width: 460, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: flow.step) { _, step in
            if step == .done { close() }
        }
    }

    @ViewBuilder private var step: some View {
        switch flow.step {
        case .choose: choose
        case .about: about
        case .words: words
        case .check: check
        case .restore: restore
        case .signOut: signOut
        case .done: EmptyView()
        }
    }

    private var choose: some View {
        Group {
            Text("Set up your account").font(.title2.bold())
            Text("Openspot signs what you publish with your account, so people can tell that an update comes from you.")
            HStack {
                Spacer()
                Button("Use existing account…") { flow.start(.restore) }
                Button("Create account", action: flow.create).keyboardShortcut(.defaultAction)
            }
        }
    }

    private var about: some View {
        Group {
            Text("Your account is 12 words").font(.title2.bold())
            Text("They are your account. There's no email, no password and no server.")
            Text("Anyone who has them can publish as you, so keep them private.")
            Text("Openspot can't reset them. If you lose them and this Mac, the account is gone.")
            HStack {
                Spacer()
                Button("Show my words", action: flow.showWords).keyboardShortcut(.defaultAction)
            }
        }
    }

    private var words: some View {
        Group {
            Text("Write down these 12 words").font(.title2.bold())
            Text("They're the only way into your account on a new Mac. Keep them private: anyone who has them can publish as you.")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), alignment: .leading, spacing: 8) {
                ForEach(Array(flow.words.enumerated()), id: \.offset) { index, word in
                    HStack(spacing: 6) {
                        Text("\(index + 1)").foregroundStyle(.secondary).monospacedDigit().frame(width: 20, alignment: .trailing)
                        Text(word).font(.body.monospaced()).textSelection(.disabled)
                    }
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Spacer()
                Button(flow.isBackedUp ? "Done" : "Later", action: close)
                Button("I wrote them down", action: flow.wroteThemDown).keyboardShortcut(.defaultAction)
            }
        }
    }

    private var check: some View {
        Group {
            Text("Check your words").font(.title2.bold())
            ForEach(Array(flow.checks.enumerated()), id: \.offset) { index, check in
                VStack(alignment: .leading, spacing: 6) {
                    Text("Word \(check.position)").foregroundStyle(.secondary)
                    HStack {
                        ForEach(check.choices, id: \.self) { word in
                            Button(word) { flow.pick(word, at: index) }
                                .buttonStyle(.bordered)
                                .tint(check.picked == word ? .accentColor : nil)
                        }
                    }
                }
            }
            if let mistake = flow.mistake {
                Text(mistake).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Show the words again", action: flow.showWordsAgain)
            }
        }
    }

    private var restore: some View {
        Group {
            Text("Sign in with your words").font(.title2.bold())
            TextField(flow.usesNsec ? "nsec1…" : "Type or paste your 12 words", text: $flow.phrase, axis: .vertical)
                .lineLimit(3...4)
                .textFieldStyle(.roundedBorder)
            Text(flow.problem ?? flow.account.map { "Sign in as \($0)" } ?? flow.counter)
                .foregroundStyle(flow.problem == nil ? Color.secondary : Color.red)
            if let replacing = flow.replacing, flow.canSignIn {
                Text(replacing).foregroundStyle(.orange)
            }
            HStack {
                Button(flow.usesNsec ? "Use your 12 words" : "Use an nsec instead") { flow.usesNsec.toggle() }
                Spacer()
                Button("Cancel", action: close)
                Button("Sign in", action: flow.signIn).keyboardShortcut(.defaultAction).disabled(!flow.canSignIn)
            }
        }
    }

    private var signOut: some View {
        Group {
            Text("Sign out of your account?").font(.title2.bold())
            Text(flow.signOutWords)
            HStack {
                Spacer()
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
                Button("Sign out", role: .destructive, action: flow.signOut)
            }
        }
    }
}
