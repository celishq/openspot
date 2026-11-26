import OpenspotCore
import SwiftUI

protocol PageView: View {}

extension PageView {
    @ViewBuilder
    func title<Icon: View, Actions: View>(_ style: PageTitle, _ icon: Icon, _ title: String, _ line: String, link: PageLink? = nil, @ViewBuilder actions: () -> Actions) -> some View {
        switch style {
        case .heading:
            Section {} header: {
                VStack(alignment: .leading, spacing: SpotTokens.settingsTitleGap) {
                    Text(title)
                        .font(SpotType.settingsTitle)
                        .foregroundStyle(.primary)
                    if !line.isEmpty {
                        Text(line)
                            .font(SpotType.settingsPageLine)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, SpotTokens.settingsHeadingGap)
                .textCase(nil)
            }
        case .banner:
            Section {
                VStack(spacing: SpotTokens.settingsBannerGap) {
                    icon
                        .padding(.bottom, SpotTokens.settingsBannerGap)
                    Text(title)
                        .font(SpotType.settingsBanner)
                    lineText(line, link)
                        .multilineTextAlignment(.center)
                    actions()
                }
                .frame(maxWidth: .infinity)
                .padding(SpotTokens.settingsBannerPadding)
            }
        case .header:
            Section {} header: {
                HStack(alignment: .center, spacing: SpotTokens.settingsCompactGap) {
                    icon
                    VStack(alignment: .leading, spacing: SpotTokens.settingsTitleGap) {
                        Text(title)
                            .font(SpotType.settingsHeader)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if !line.isEmpty || link != nil {
                            lineText(line, link)
                                .font(SpotType.settingsPageLine)
                        }
                    }
                    Spacer(minLength: SpotTokens.settingsTrailingGap)
                    HStack(spacing: SpotTokens.settingsValueGap) { actions() }
                        .controlSize(.large)
                        .fixedSize()
                }
                .padding(.bottom, SpotTokens.settingsHeadingGap)
                .textCase(nil)
            }
        case .hero:
            Section {} header: {
                VStack(spacing: SpotTokens.settingsHeroGap) {
                    icon
                    if !title.isEmpty {
                        Text(title)
                            .font(SpotType.settingsHero)
                            .foregroundStyle(.primary)
                    }
                    lineText(line, link)
                        .font(SpotType.settingsPageLine)
                        .multilineTextAlignment(.center)
                    actions()
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, SpotTokens.settingsHeadingGap)
                .textCase(nil)
            }
        }
    }

    private func lineText(_ line: String, _ link: PageLink?) -> some View {
        let words: Text
        if let link {
            var title = AttributedString(link.title.replacingOccurrences(of: " ", with: "\u{00A0}"))
            title.link = PageTitle.linkURL
            words = Text("\(line) \(title)")
        } else {
            words = Text(line)
        }
        return words
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { _ in
                link?.action()
                return .handled
            })
    }

    func group<Rows: View>(_ title: String?, @ViewBuilder _ rows: () -> Rows) -> some View {
        Section {
            rows()
        } header: {
            if let title {
                Text(title)
                    .font(SpotType.settingsGroup)
                    .foregroundStyle(.primary)
            }
        }
    }

    func folding<Rows: View>(_ title: String, isFolded: Binding<Bool>, @ViewBuilder _ rows: () -> Rows) -> some View {
        Section {
            if !isFolded.wrappedValue {
                rows()
            }
        } header: {
            HStack {
                Text(title)
                    .font(SpotType.settingsGroup)
                    .foregroundStyle(.primary)
                Spacer(minLength: SpotTokens.settingsTrailingGap)
                Button(isFolded.wrappedValue ? "Show" : "Hide") {
                    withAnimation(SpotMotion.fade(isShown: isFolded.wrappedValue)) { isFolded.wrappedValue.toggle() }
                }
                .buttonStyle(.link)
            }
        }
    }

    func tiles<Tiles: View>(note: String? = nil, @ViewBuilder _ tiles: () -> Tiles) -> some View {
        Section {} header: {
            VStack(alignment: .leading, spacing: SpotTokens.pageTileGap) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpotTokens.pageTileGap), count: SpotTokens.pageTileColumns), spacing: SpotTokens.pageTileGap) {
                    tiles()
                }
                .padding(.horizontal, -SpotTokens.pageTileBleed)
                if let note {
                    Text(note)
                        .font(SpotType.settingsLine)
                        .foregroundStyle(.secondary)
                }
            }
            .textCase(nil)
            .foregroundStyle(.primary)
        }
    }

    func lines<Item: Identifiable, Line: View>(_ items: [Item], @ViewBuilder _ line: @escaping (Item) -> Line) -> some View {
        ForEach(items) { line($0) }
    }

    func row<Content: View>(action: @escaping () -> Void, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: SpotTokens.settingsRowGap) {
            content()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityAddTraits(.isButton)
    }

    func plain(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
    }

    func titled(_ title: String, _ line: String) -> some View {
        VStack(alignment: .leading, spacing: SpotTokens.settingsLineGap) {
            Text(title)
                .lineLimit(1)
            if !line.isEmpty {
                Text(line)
                    .font(SpotType.settingsLine)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    var chevron: some View {
        Image(systemName: "chevron.right")
            .font(SpotType.settingsChevron)
            .foregroundStyle(.tertiary)
    }
}
