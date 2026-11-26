import OpenspotCore
import SwiftUI

extension SettingsView {
    var results: some View {
        let found = book.found
        return Group {
            title(.heading, EmptyView(), "Results for “\(book.query)”", found.isEmpty ? "No row matches. Check the spelling, or try other words." : "Every row of every section that matches.") {}
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
                        if row.kind == .key {
                            keyLine(row, title: "\(row.name) · \(row.title)")
                        } else {
                            self.row(action: { book.reveal(row) }) {
                                Text("\(row.name) · \(row.title)")
                                    .lineLimit(1)
                                Spacer(minLength: SpotTokens.settingsTrailingGap)
                                if row.kind != .secret {
                                    Text(book.value(of: row).word).foregroundStyle(.secondary).lineLimit(1)
                                }
                                chevron
                            }
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
                Toggle("", isOn: Binding(get: { book.value(of: row).isOn }, set: { isOn in act { await $0.set(row, on: isOn) } }))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            case .field, .text:
                TextField("Not set", text: draft(row))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: SpotTokens.settingsFieldWidth)
                    .onSubmit { submit(row, drafts[row.item] ?? row.value ?? "") }
            case .choice where !row.choices.isEmpty:
                Picker("", selection: Binding(get: { book.value(of: row).text }, set: { value in submit(row, value) })) {
                    if book.value(of: row) == .unset { Text(SettingValue.unset.word).tag("") }
                    ForEach(row.choices, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            case .secret:
                SecureField(book.value(of: row).word, text: draft(row, blank: true))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: SpotTokens.settingsFieldWidth)
                    .onSubmit { keep(row) }
                    .onKeyPress(.delete) {
                        guard (drafts[row.item] ?? "").isEmpty, book.value(of: row) != .unset else { return .ignored }
                        act { await $0.remove(row) }
                        return .handled
                    }
            default:
                Text(book.value(of: row).word).foregroundStyle(.secondary)
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

    func title(of section: SettingsPage.Section) -> some View {
        title(.banner, SettingsTile(symbol: section.symbol, color: SpotTheme.settings(section), side: SpotTokens.settingsBannerTile), section.title, section.line) {}
    }

    func row<Content: View>(open page: SettingsPage, @ViewBuilder _ content: () -> Content) -> some View {
        row(action: { book.go(page) }, content)
    }
}
