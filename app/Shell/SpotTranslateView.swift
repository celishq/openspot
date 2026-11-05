import AppKit
import NaturalLanguage
import OpenspotCore
import SwiftUI
import Translation

/// The translate screen: two languages, a swap, the text to translate and its translation.
struct SpotTranslateView: View {
    /// What the output area says in place of a translation.
    private enum Notice: Equatable {
        case missing(from: String, to: String)
        case unsupported
        case unknownLanguage
        case failed(String)
    }

    private struct Request: Equatable {
        let input: String
        let source: String?
        let target: String
        let retry: Int
    }

    private struct Language: Identifiable {
        let id: String
        let name: String
    }

    private static let settings = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension")
    private static let pause: Duration = .milliseconds(300)
    static let hint = "⌘⏎ Copy   ⌘⇧S Swap   Esc Close"
    private static let disabledOpacity = 0.5
    private static let editorInset: CGFloat = 5

    let model: SpotsModel
    @State private var languages: [Language] = []
    @State private var notice: Notice?
    @State private var retry = 0
    @State private var download: TranslationSession.Configuration?
    @FocusState private var isInputFocused: Bool

    private var draft: TranslationDraft { model.translation }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }

    private var request: Request {
        Request(input: draft.input, source: draft.source, target: draft.target, retry: retry)
    }

    var body: some View {
        VStack(spacing: SpotTokens.formFieldGap) {
            VStack(spacing: 0) {
                inputPane
                Rectangle()
                    .fill(.white.opacity(SpotTokens.fill))
                    .frame(height: 1)
                    .padding(.trailing, SpotTokens.padding + SpotTokens.glyphSize + SpotTokens.placeGap)
                outputPane
            }
            .background(Color.white.opacity(SpotTokens.fill), in: shape)
            .overlay(alignment: .trailing) { swapButton }
        }
        .task { await loadLanguages() }
        .task(id: request) { await translate() }
        .translationTask(download) { session in
            nonisolated(unsafe) let session = session
            try? await session.prepareTranslation()
            await finishDownload()
        }
        .onAppear { focusInput() }
        .onChange(of: model.isShown) { _, isShown in
            if isShown { DispatchQueue.main.asyncAfter(deadline: .now() + SpotMotion.fadeInDuration) { focusInput() } }
        }
    }

    private var swapButton: some View {
        SpotRoundButton(symbol: "arrow.up.arrow.down", label: "Swap languages") { model.swapTranslation() }
            .disabled(!draft.canSwap)
            .opacity(draft.canSwap ? 1 : Self.disabledOpacity)
            .padding(.trailing, SpotTokens.padding)
    }

    private func languageMenu(_ title: String, @ViewBuilder choices: () -> some View) -> some View {
        Menu {
            choices()
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(SpotType.detail)
                    .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .modifier(SpotSecondaryText())
            }
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sourceMenu: some View {
        languageMenu(automaticTitle) {
            Picker("From", selection: Binding(get: { draft.source }, set: { model.translation.choose(source: $0) })) {
                Text(automaticTitle).tag(String?.none)
                Divider()
                ForEach(languages) { Text($0.name).tag(String?.some($0.id)) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    private var targetMenu: some View {
        languageMenu(name(of: draft.target)) {
            Picker("To", selection: Binding(get: { draft.target }, set: { model.translation.choose(target: $0) })) {
                ForEach(languages) { Text($0.name).tag($0.id) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    /// The menu of the input language, or the language it found.
    private var automaticTitle: String {
        if let source = draft.source { return name(of: source) }
        return draft.detected.map { "Auto (\(name(of: $0)))" } ?? "Automatic"
    }

    private var inputPane: some View {
        VStack(spacing: SpotTokens.formLabelGap) {
            sourceMenu
            ZStack(alignment: .topLeading) {
                TextEditor(text: Binding(get: { draft.input }, set: { model.translation.input = $0 }))
                    .scrollContentBackground(.hidden)
                    .font(SpotType.body)
                    .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                    .focused($isInputFocused)
                    .padding(.horizontal, -Self.editorInset)
                if draft.input.isEmpty {
                    Text("Type or paste text")
                        .font(SpotType.body)
                        .foregroundStyle(.white.opacity(SpotTokens.secondaryLight))
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(SpotTokens.padding)
        .frame(maxHeight: .infinity)
    }

    private var outputPane: some View {
        VStack(spacing: SpotTokens.formLabelGap) {
            targetMenu
            if let notice {
                noticeView(notice)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    Text(draft.output.isEmpty ? "Translation" : draft.output)
                        .font(SpotType.body)
                        .foregroundStyle(.white.opacity(draft.output.isEmpty ? SpotTokens.secondaryLight : SpotTokens.titleOpacity))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
                if !draft.output.isEmpty {
                    noticeButton("Copy") { model.copyTranslation() }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(SpotTokens.padding)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func noticeView(_ notice: Notice) -> some View {
        VStack(spacing: SpotTokens.placeGap) {
            Text(words(for: notice))
                .font(SpotType.body)
                .modifier(SpotSecondaryText())
                .multilineTextAlignment(.center)
            if case .missing(let from, let to) = notice {
                HStack(spacing: SpotTokens.placeGap) {
                    noticeButton("Download") { startDownload(from: from, to: to) }
                    noticeButton("Open Settings") {
                        if let url = Self.settings { NSWorkspace.shared.open(url) }
                    }
                }
            }
        }
        .padding(SpotTokens.padding)
    }

    private func noticeButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(SpotType.detail)
                .foregroundStyle(.white)
                .padding(.horizontal, SpotTokens.padding)
                .padding(.vertical, 6)
                .background(Color.white.opacity(SpotTokens.selectedFill), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func words(for notice: Notice) -> String {
        switch notice {
        case .missing(let from, let to): "\(name(of: from)) to \(name(of: to)) is not installed"
        case .unsupported: "macOS cannot translate between these languages"
        case .unknownLanguage: "Choose the language of this text"
        case .failed(let reason): reason
        }
    }

    private func name(of code: String) -> String {
        languages.first { $0.id == code }?.name ?? Locale.current.localizedString(forIdentifier: code) ?? code
    }

    private func focusInput() {
        DispatchQueue.main.async { isInputFocused = true }
    }

    private func loadLanguages() async {
        let found = await Self.supportedLanguages()
        languages = found
            .map { Language(id: $0.minimalIdentifier, name: Locale.current.localizedString(forIdentifier: $0.minimalIdentifier) ?? $0.minimalIdentifier) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    /// Translates the input after a short pause. A newer request cancels this one, so an older answer never shows.
    private func translate() async {
        guard draft.hasInput else {
            notice = nil
            model.translation.take(output: "")
            model.translation.take(detected: nil)
            return
        }
        try? await Task.sleep(for: Self.pause)
        guard !Task.isCancelled else { return }
        if draft.source == nil {
            model.translation.take(detected: NLLanguageRecognizer.dominantLanguage(for: draft.input)?.rawValue)
        }
        guard let code = draft.from else {
            notice = .unknownLanguage
            return
        }
        guard draft.needsTranslation else {
            notice = nil
            model.translation.take(output: draft.input)
            return
        }
        let from = Locale.Language(identifier: code)
        let to = Locale.Language(identifier: draft.target)
        switch await Self.status(from: from, to: to) {
        case .installed:
            do {
                let answer = try await Self.translation(of: draft.input, from: from, to: to)
                guard !Task.isCancelled else { return }
                notice = nil
                model.translation.take(output: answer)
            } catch {
                if !Task.isCancelled { notice = .failed(error.localizedDescription) }
            }
        case .supported:
            notice = .missing(from: code, to: draft.target)
        default:
            notice = .unsupported
        }
    }

    private nonisolated static func supportedLanguages() async -> [Locale.Language] {
        await LanguageAvailability().supportedLanguages
    }

    private nonisolated static func status(from: Locale.Language, to: Locale.Language) async -> LanguageAvailability.Status {
        await LanguageAvailability().status(from: from, to: to)
    }

    private nonisolated static func translation(of text: String, from: Locale.Language, to: Locale.Language) async throws -> String {
        if #available(macOS 26.4, *) {
            return try await TranslationSession(installedSource: from, target: to, preferredStrategy: .highFidelity).translate(text).targetText
        }
        return try await TranslationSession(installedSource: from, target: to).translate(text).targetText
    }

    private func startDownload(from: String, to: String) {
        model.isDownloadingLanguage = true
        download = TranslationSession.Configuration(source: Locale.Language(identifier: from), target: Locale.Language(identifier: to))
    }

    private func finishDownload() {
        model.isDownloadingLanguage = false
        download = nil
        retry += 1
    }
}
