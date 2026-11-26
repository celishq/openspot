import OpenspotCore
import SwiftUI

protocol PageView: View {}

extension PageView {
    @ViewBuilder
    func title<Icon: View, Actions: View>(_ style: PageTitle, _ icon: Icon, _ title: String, _ line: String, @ViewBuilder actions: () -> Actions) -> some View {
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
        case .header:
            Section {
                HStack(alignment: .center, spacing: SpotTokens.settingsHeaderGap) {
                    icon
                    VStack(alignment: .leading, spacing: SpotTokens.settingsTitleGap) {
                        Text(title)
                            .font(SpotType.settingsHeader)
                        if !line.isEmpty {
                            Text(line)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        actions()
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, SpotTokens.settingsHeaderPadding)
            }
        case .hero:
            Section {} header: {
                VStack(spacing: SpotTokens.settingsHeroGap) {
                    icon
                    Text(title)
                        .font(SpotType.settingsHero)
                        .foregroundStyle(.primary)
                    Text(line)
                        .font(SpotType.settingsPageLine)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    actions()
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, SpotTokens.settingsHeadingGap)
                .textCase(nil)
            }
        }
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
