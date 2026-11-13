import SwiftUI

/// The steps of the Account spot: what the 12 words are, the words, a check of 2 of them, the sign-in with one phrase
/// field that numbers each word as a chip, the account, and the sign-out. The script decides the step and gives each
/// fact; the view keeps only what the person types or picks, and sends it to the script.
struct SpotView: View {
    let spot: SpotInput
    @State private var phrase = ""
    @State private var picks: [String: String] = [:]
    @FocusState private var isTyping: Bool

    private static let gap: CGFloat = 10
    private static let radius: CGFloat = 8
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 6, alignment: .leading), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            switch spot["step"] {
            case "about": about
            case "words": words
            case "check": check
            case "restore": restore
            case "account": account
            case "leave": leave
            default: choose
            }
            if let mistake = spot["mistake"] {
                Text(mistake).font(spot.font.detail).foregroundStyle(.red)
            }
            Spacer(minLength: 0)
        }
        .font(spot.font.title.weight(.regular))
        .foregroundStyle(spot.ink)
        .frame(width: spot.size.width, height: spot.size.height, alignment: .topLeading)
    }

    private var choose: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            heading("Set up your account")
            secondary("Openspot signs what you publish with your account, so people can tell that an update comes from you.")
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
            secondary("On paper, in this order.")
            LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 4) {
                ForEach(Array(spot.all("word").enumerated()), id: \.offset) { index, word in
                    chip(index + 1, word, isKnown: true)
                }
            }
        }
    }

    private var check: some View {
        let places = spot.all("check")
        let choices = spot.all("choice")
        return VStack(alignment: .leading, spacing: Self.gap) {
            heading("Check your words")
            ForEach(Array(places.enumerated()), id: \.offset) { index, place in
                VStack(alignment: .leading, spacing: 6) {
                    secondary("Word \(place)")
                    choiceGrid(Array(choices.dropFirst(index * 4).prefix(4)), at: place, of: places)
                }
            }
        }
    }

    private func choiceGrid(_ words: [String], at place: String, of places: [String]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
            ForEach(words, id: \.self) { word in
                Button { pick(word, at: place, of: places) } label: {
                    Text(word)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(fill(isOn: picks[place] == word), in: RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var restore: some View {
        let isNsec = spot["mode"] == "nsec"
        let typed = phrase.split(whereSeparator: \.isWhitespace).map(String.init)
        let unknown = Set((spot["unknown"] ?? "").split(separator: " ").compactMap { Int($0) })
        return VStack(alignment: .leading, spacing: Self.gap) {
            heading(isNsec ? "Sign in with your nsec" : "Sign in with your words")
            TextField(isNsec ? "nsec1…" : "Type or paste your 12 words", text: $phrase, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...3)
                .focused($isTyping)
                .padding(8)
                .background(fill(isOn: false), in: RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
                .onChange(of: phrase) { _, text in spot.send("phrase \(text)") }
                .onKeyPress(.tab) {
                    guard let completion = spot["completion"], let last = typed.last, phrase.last?.isWhitespace == false else { return .ignored }
                    phrase = String(phrase.dropLast(last.count)) + completion + " "
                    return .handled
                }
                .onSubmit { if spot["account"] != nil { spot.send("sign-in \(phrase)") } }
                .onAppear { isTyping = true }
            if !isNsec, !typed.isEmpty {
                LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 4) {
                    ForEach(Array(typed.enumerated()), id: \.offset) { index, word in
                        chip(index + 1, word, isKnown: !unknown.contains(index + 1))
                    }
                }
            }
            status
        }
    }

    /// The line under the sign-in field: what is wrong, the account it signs in to with its button, or how far it is.
    @ViewBuilder private var status: some View {
        if let problem = spot["problem"] {
            Text(problem).font(spot.font.detail).foregroundStyle(.red)
        } else if let account = spot["account"] {
            HStack {
                Text("Signs in as \(short(account))").font(spot.font.detail).foregroundStyle(.green)
                Spacer()
                Button("Sign in ⏎") { spot.send("sign-in \(phrase)") }
                    .buttonStyle(.plain)
                    .font(spot.font.detail.weight(.semibold))
                    .foregroundStyle(spot.accent)
            }
        } else if let completion = spot["completion"] {
            secondary("Tab: \(completion)").font(spot.font.detail)
        } else if let counter = spot["counter"] {
            secondary(counter).font(spot.font.detail)
        }
    }

    private var account: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            heading("Your account")
            secondary("Openspot signs what you publish with it.")
            if let npub = spot["npub"] {
                Text(short(npub)).font(spot.font.title.monospaced()).textSelection(.enabled)
            }
            if spot["backed"] == "true" {
                point("checkmark.shield", "Your 12 words are backed up.")
            } else {
                point("exclamationmark.triangle", "Your 12 words are not backed up yet.")
            }
        }
    }

    private var leave: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            heading("Sign out of your account?")
            secondary("Openspot removes your account from \(spot["place"] ?? "this Mac"). You can sign in again with your 12 words.")
        }
    }

    /// Keeps a pick, and sends both picks once each place has one.
    private func pick(_ word: String, at place: String, of places: [String]) {
        picks[place] = word
        let chosen = places.compactMap { place in picks[place].map { "\(place) \($0)" } }
        if chosen.count == places.count { spot.send("checked \(chosen.joined(separator: " "))") }
    }

    private func heading(_ words: String) -> some View {
        Text(words).font(spot.font.value)
    }

    private func secondary(_ words: String) -> some View {
        Text(words).opacity(spot.secondary).fixedSize(horizontal: false, vertical: true)
    }

    private func point(_ symbol: String, _ words: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).frame(width: 18).opacity(spot.secondary)
            Text(words).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func chip(_ number: Int, _ word: String, isKnown: Bool) -> some View {
        HStack(spacing: 4) {
            Text("\(number)").font(spot.font.detail).monospacedDigit().opacity(spot.secondary)
            Text(word).foregroundStyle(isKnown ? spot.ink : .red).lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill(isOn: false), in: RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
    }

    private func fill(isOn: Bool) -> Color {
        isOn ? spot.accent.opacity(0.35) : spot.ink.opacity(0.08)
    }

    private func short(_ npub: String) -> String {
        "\(npub.prefix(12))…\(npub.suffix(6))"
    }
}
