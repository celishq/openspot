import OpenspotCore
import SwiftUI

extension SettingsView {
    var results: some View {
        let found = facts.found(book.query)
        return Group {
            heading("Results for “\(book.query)”", found.isEmpty ? "No row matches. Check the spelling, or try other words." : "Every row of every section that matches.")
            if !found.accesses.isEmpty {
                group("Access") {
                    lines(found.accesses) { access in
                        row(open: .accessOf(access.id)) {
                            SettingsTile(access: access.id, side: SpotTokens.settingsFoundTile)
                            Text(access.id.title)
                            Spacer(minLength: SpotTokens.settingsTrailingGap)
                            Text(access.status.word).foregroundStyle(SpotTheme.settings(access.status))
                            chevron
                        }
                    }
                }
            }
            if !found.standings.isEmpty {
                group("Spots") {
                    lines(found.standings) { spotLine($0) }
                }
            }
            if !found.rows.isEmpty {
                group("Settings") {
                    lines(found.rows) { row in
                        self.row(action: { book.reveal(row) }) {
                            Text("\(row.name) · \(row.title)")
                                .lineLimit(1)
                            Spacer(minLength: SpotTokens.settingsTrailingGap)
                            if row.kind == .key {
                                keycaps(row).allowsHitTesting(false)
                            } else if row.kind != .secret {
                                Text(book.display(row)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            chevron
                        }
                    }
                }
            }
        }
    }

    func settingLine(_ row: SettingRow) -> some View {
        HStack(spacing: SpotTokens.settingsValueGap) {
            titled(row.title, row.detail ?? "")
            Spacer(minLength: SpotTokens.settingsValueGap)
            switch row.kind {
            case .key:
                keycaps(row)
            case .toggle:
                Toggle("", isOn: Binding(get: { book.value(of: row) == "true" }, set: { isOn in act { await $0.set(row, to: isOn ? "true" : "false") } }))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            case .field, .text:
                TextField("Not set", text: draft(row))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: SpotTokens.settingsFieldWidth)
                    .onSubmit { submit(row, drafts[row.item] ?? row.value ?? "") }
            case .choice where !(row.options ?? "").isEmpty:
                Picker("", selection: Binding(get: { book.shown(row) }, set: { value in submit(row, value) })) {
                    if book.shown(row).isEmpty { Text("Not set").tag("") }
                    ForEach((row.options ?? "").split(separator: ",").map(String.init), id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            case .secret:
                SecureField(book.value(of: row).isEmpty ? "Not set" : "Set", text: draft(row, blank: true))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: SpotTokens.settingsFieldWidth)
                    .onSubmit { keep(row) }
                    .onKeyPress(.delete) {
                        guard (drafts[row.item] ?? "").isEmpty, !book.value(of: row).isEmpty else { return .ignored }
                        act { await $0.remove(row) }
                        return .handled
                    }
            default:
                Text(book.display(row)).foregroundStyle(.secondary)
            }
        }
        .listRowBackground(book.target == row.item ? Color.accentColor.opacity(SpotTheme.settingsTarget) : nil)
        .id(row.item)
    }

    private func draft(_ row: SettingRow, blank: Bool = false) -> Binding<String> {
        Binding(get: { drafts[row.item] ?? (blank ? "" : row.value ?? "") }, set: { drafts[row.item] = $0 })
    }

    private func submit(_ row: SettingRow, _ value: String) {
        drafts[row.item] = nil
        act { await $0.set(row, to: value) }
    }

    private func keep(_ row: SettingRow) {
        guard let value = drafts[row.item], !value.isEmpty else { return }
        drafts[row.item] = nil
        act { await $0.keep(secret: value, of: row) }
    }

    func pageHeader(_ section: SettingsPage.Section) -> some View {
        heading(section.title, section.page.line)
    }

    func header<Trailing: View>(_ icon: some View, _ title: String, _ text: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        header(icon, title, text, trailing: trailing) {}
    }

    func header<Trailing: View, Accessory: View>(_ icon: some View, _ title: String, _ text: String, @ViewBuilder trailing: () -> Trailing, @ViewBuilder accessory: () -> Accessory) -> some View {
        Section {
            HStack(alignment: .center, spacing: SpotTokens.settingsHeaderGap) {
                icon
                VStack(alignment: .leading, spacing: SpotTokens.settingsTitleGap) {
                    Text(title)
                        .font(SpotType.settingsHeader)
                    if !text.isEmpty {
                        Text(text)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    trailing()
                }
                Spacer(minLength: 0)
                accessory()
            }
            .padding(.vertical, SpotTokens.settingsHeaderPadding)
        }
    }

    func heading(_ title: String, _ line: String) -> some View {
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

    func row<Content: View>(open page: SettingsPage, @ViewBuilder _ content: () -> Content) -> some View {
        row(action: { book.go(page) }, content)
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
