import OpenspotCore
import SwiftUI

/// The steps of the account window, drawn from its flow. It closes once the flow is done.
struct AccountView: View {
    @Bindable var flow: AccountFlow
    let close: () -> Void
    @FocusState private var focused: Int?

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
            Text("Type or paste your 12 words. You can paste an nsec into the first box too.")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(0..<AccountFlow.wordCount, id: \.self) { index in
                    HStack(spacing: 6) {
                        Text("\(index + 1)").foregroundStyle(.secondary).monospacedDigit().frame(width: 20, alignment: .trailing)
                        TextField("", text: box(index))
                            .textFieldStyle(.roundedBorder)
                            .focused($focused, equals: index)
                            .foregroundStyle(flow.unknownBoxes.contains(index) && focused != index ? .red : .primary)
                            .onSubmit { focused = index + 1 < AccountFlow.wordCount ? index + 1 : nil }
                    }
                }
            }
            if let index = focused, !flow.boxes[index].isEmpty, AccountFlow.suggestions(for: flow.boxes[index]) != [flow.boxes[index]] {
                suggestions(for: index)
            }
            if let problem = flow.problem {
                Text(problem).foregroundStyle(.red)
            } else if let replacing = flow.replacing, flow.canSignIn {
                Text(replacing).foregroundStyle(.orange)
            }
            HStack {
                Spacer()
                Button("Cancel", action: close)
                Button("Sign in", action: flow.signIn).keyboardShortcut(.defaultAction).disabled(!flow.canSignIn)
            }
        }
        .onAppear { focused = 0 }
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

    private func suggestions(for index: Int) -> some View {
        HStack {
            ForEach(AccountFlow.suggestions(for: flow.boxes[index]).prefix(4), id: \.self) { word in
                Button(word) {
                    flow.boxes[index] = word
                    focused = index + 1 < AccountFlow.wordCount ? index + 1 : nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    /// A box that takes a pasted phrase whole.
    private func box(_ index: Int) -> Binding<String> {
        Binding(
            get: { flow.boxes[index] },
            set: { text in
                if text.contains(where: \.isWhitespace), text.split(whereSeparator: \.isWhitespace).count > 1 {
                    flow.paste(text)
                    focused = nil
                } else {
                    flow.boxes[index] = text.trimmingCharacters(in: .whitespaces)
                }
            }
        )
    }
}
