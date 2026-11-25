import OpenspotCore
import SwiftUI

struct SettingsAccountSheet: View {
    enum Step: String, Identifiable {
        case how, handle, signIn, words, check, leave

        var id: Self {
            self
        }
    }

    let book: SettingsBook
    @Binding var step: Step?
    @State private var shown: Step
    @State private var handle = ""
    @State private var phrase = ""
    @State private var words: [String] = []
    @State private var check: [Int] = []
    @State private var choices: [[String]] = []
    @State private var picks: [Int: String] = [:]
    @State private var failure: String?

    init(book: SettingsBook, step: Binding<Step?>) {
        self.book = book
        _step = step
        _shown = State(initialValue: step.wrappedValue ?? .how)
    }

    private var account: SettingsFacts.Account? {
        book.account
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.settingsSheetGap) {
            switch shown {
            case .how: how
            case .handle: handleStep
            case .signIn: signIn
            case .words: wordsStep
            case .check: checkStep
            case .leave: leave
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(SpotTokens.settingsSheetPadding)
        .frame(width: SpotTokens.settingsSheetWidth, alignment: .leading)
        .onChange(of: step) { if let step { shown = step } }
        .onDisappear(perform: forget)
    }

    private func title(_ title: String, _ line: String) -> some View {
        VStack(alignment: .leading, spacing: SpotTokens.settingsTitleGap) {
            Text(title)
                .font(SpotType.settingsTitle)
            Text(line)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func fact(_ text: String, _ symbol: String, _ color: Color = .secondary) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
    }

    private func buttons<Main: View>(@ViewBuilder _ main: () -> Main) -> some View {
        HStack(spacing: SpotTokens.settingsRowGap) {
            Spacer()
            Button("Cancel") { step = nil }
                .keyboardShortcut(.cancelAction)
            main()
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .controlSize(.large)
        .padding(.top, SpotTokens.settingsSheetTop)
    }

    private var how: some View {
        Group {
            title("How your key works", "Openspot signs each spot you publish with your key. There is no email, password or server.")
            VStack(alignment: .leading, spacing: SpotTokens.settingsRowGap) {
                fact("Shows an update is yours", "checkmark.seal")
                fact("Kept in iCloud Keychain", "icloud")
                fact("12 words bring it back", "list.number")
                fact("Anyone with the words is you", "eye.slash")
                fact("Nobody can reset them", "exclamationmark.triangle", SpotTheme.settingsLate)
            }
            HStack {
                Spacer()
                Button("Done") { step = nil }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.top, SpotTokens.settingsSheetTop)
        }
    }

    private var handleStep: some View {
        Group {
            title("Pick your handle", "It names you on the spots you publish, and in their links.")
            TextField("yourname", text: $handle)
                .textFieldStyle(.roundedBorder)
                .onSubmit(create)
            buttons {
                Button("Create Key", action: create)
                    .disabled(handle.isEmpty)
            }
        }
    }

    private func create() {
        guard !handle.isEmpty else { return }
        let handle = handle
        step = nil
        Task { await book.makeAccount(handle: handle) }
    }

    private var signIn: some View {
        let line = book.line(of: phrase)
        return Group {
            title("Use your own key", "Type your 12 words, or an nsec. Openspot asks for Touch ID before it signs in.")
            TextEditor(text: $phrase)
                .font(.body.monospaced())
                .frame(height: SpotTokens.settingsPhraseHeight)
                .scrollContentBackground(.hidden)
                .padding(SpotTokens.settingsPhrasePadding)
                .background(Color.primary.opacity(SpotTheme.settingsQuietFill), in: SpotRoundShape(radius: SpotTokens.settingsPhraseCorner))
            if let failure {
                fact(failure, "exclamationmark.triangle", SpotTheme.settingsClash)
            } else if let words = line["title"] {
                HStack(spacing: SpotTokens.settingsUseGap) {
                    fact(words, line["icon"] ?? "info.circle", SpotTheme.settingsTone(line["tone"]))
                    if let detail = line["detail"] {
                        Text(detail).foregroundStyle(.secondary).font(.body.monospaced())
                    }
                }
            }
            buttons {
                Button("Sign In") { signInNow() }
                    .disabled(line["detail"] == nil)
            }
        }
        .onChange(of: phrase) { failure = nil }
    }

    private func signInNow() {
        let typed = phrase
        Task {
            if let failure = await book.signIn(typed) {
                self.failure = failure
            } else {
                step = nil
                book.say("Signed in")
            }
        }
    }

    private var wordsStep: some View {
        let isSaved = account?.isBackedUp == true
        return Group {
            title("Write them down", "In this order. Anyone with them is you, and nobody can reset them.")
            if let failure {
                fact(failure, "exclamationmark.triangle", SpotTheme.settingsClash)
            }
            Grid(alignment: .leading, horizontalSpacing: SpotTokens.settingsWordsGapX, verticalSpacing: SpotTokens.settingsWordsGapY) {
                ForEach(0..<(words.count + 2) / 3, id: \.self) { line in
                    GridRow {
                        ForEach(0..<3, id: \.self) { column in
                            let index = line * 3 + column
                            if index < words.count {
                                HStack(spacing: SpotTokens.settingsUseGap) {
                                    Text("\(index + 1)").foregroundStyle(.secondary).monospacedDigit().frame(width: SpotTokens.settingsWordsNumber, alignment: .trailing)
                                    Text(words[index]).font(.body.monospaced())
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, SpotTokens.settingsTitleGap)
            HStack(spacing: SpotTokens.settingsRowGap) {
                Spacer()
                Button(isSaved ? "Done" : "Later") { step = nil }
                    .keyboardShortcut(.cancelAction)
                if !words.isEmpty, !isSaved {
                    Button("I Wrote Them Down") { wrote() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)
            .padding(.top, SpotTokens.settingsSheetTop)
        }
        .task { await reveal() }
    }

    private func reveal() async {
        guard words.isEmpty else { return }
        let shown = await book.words()
        words = shown.words
        failure = shown.failure
    }

    private func wrote() {
        words = []
        if account?.sync == true { return step = nil }
        let places = Array((1...12).shuffled().prefix(2)).sorted()
        check = places
        choices = book.choices(at: places)
        picks = [:]
        failure = nil
        step = .check
    }

    private var checkStep: some View {
        Group {
            title("Pick each word you wrote", "Openspot checks two of them, so you know your words bring your key back.")
            if let failure {
                fact(failure, "exclamationmark.triangle", SpotTheme.settingsClash)
            }
            ForEach(Array(zip(check, choices)), id: \.0) { place, offered in
                VStack(alignment: .leading, spacing: SpotTokens.settingsUseGap) {
                    Text("Word \(place)").fontWeight(.semibold)
                    HStack(spacing: SpotTokens.settingsGroupGap) {
                        ForEach(offered, id: \.self) { word in
                            Button(word) { pick(word, at: place) }
                                .buttonStyle(.bordered)
                                .tint(picks[place] == word ? .accentColor : nil)
                        }
                    }
                }
            }
            HStack(spacing: SpotTokens.settingsRowGap) {
                Button("Show the Words Again") { step = .words }
                Spacer()
                Button("Later") { step = nil }
                    .keyboardShortcut(.cancelAction)
            }
            .controlSize(.large)
            .padding(.top, SpotTokens.settingsSheetTop)
        }
    }

    private func pick(_ word: String, at place: Int) {
        picks[place] = word
        failure = nil
        guard check.allSatisfy({ picks[$0] != nil }) else { return }
        let places = check, picked = check.compactMap { picks[$0] }
        Task {
            if let failure = await book.confirm(places, picked) {
                self.failure = failure
                picks = [:]
            } else {
                step = nil
                book.say("Your words are backed up")
            }
        }
    }

    private var leave: some View {
        let place = account?.sync == true ? "all your Macs" : "this Mac"
        let isSaved = account?.isBackedUp == true
        return Group {
            title("Sign out of your account?", "It leaves \(place)." + (isSaved ? " Your 12 words sign you in again." : ""))
            if !isSaved {
                HStack {
                    fact("You haven't saved its words", "exclamationmark.triangle", SpotTheme.settingsClash)
                    Spacer()
                    Button("Show My Words…") { step = .words }
                }
            }
            HStack(spacing: SpotTokens.settingsRowGap) {
                Spacer()
                Button("Cancel") { step = nil }
                    .keyboardShortcut(.cancelAction)
                Button("Sign Out", role: .destructive) {
                    step = nil
                    Task { await book.signOut() }
                }
                .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.top, SpotTokens.settingsSheetTop)
        }
    }

    private func forget() {
        words = []
        phrase = ""
        picks = [:]
        failure = nil
    }
}
