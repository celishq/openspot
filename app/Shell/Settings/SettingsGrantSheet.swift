import AppKit
import OpenspotCore
import SwiftUI

struct SettingsGrantSheet: View {
    let book: SettingsBook
    let grant: AccessGrant

    var body: some View {
        let name = book.facts.standing(grant.spot)?.title ?? grant.spot
        let shape = SpotRoundShape(radius: SpotTokens.settingsGrantCorner)
        ZStack(alignment: .top) {
            SpotTheme.settingsDim
                .ignoresSafeArea()
                .contentShape(Rectangle())
            VStack(alignment: .leading, spacing: SpotTokens.settingsSheetGap) {
                VStack(alignment: .leading, spacing: SpotTokens.settingsTitleGap) {
                    Text(grant.title(of: name))
                        .font(SpotType.settingsHeader)
                    Text(grant.line)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(grant.steps.enumerated()), id: \.element) { index, access in
                        if index > 0 { Divider().padding(.vertical, SpotTokens.settingsRowGap) }
                        step(access, number: index + 1)
                    }
                }
                HStack(spacing: SpotTokens.settingsRowGap) {
                    Spacer()
                    Button("Not now") { Task { await book.endGrant() } }
                        .keyboardShortcut(.cancelAction)
                    if grant.step?.needsRestart == true {
                        Button("Restart Openspot") { Task { await book.restart() } }
                            .buttonStyle(.borderedProminent)
                    } else if let now = grant.step {
                        Button("Open System Settings") { book.openPane(of: now) }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .controlSize(.large)
            }
            .padding(SpotTokens.settingsGrantPadding)
            .frame(width: SpotTokens.settingsSheetWidth, alignment: .leading)
            .background(Color(nsColor: .windowBackgroundColor), in: shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(SpotTheme.settingsStepFill), lineWidth: SpotTokens.settingsRim))
            .shadow(color: SpotTheme.settingsSheetShadow, radius: SpotTokens.settingsGrantShadow, y: SpotTokens.settingsGrantDrop)
            .padding(.top, SpotTokens.settingsHeaderTile)
        }
    }

    private func step(_ access: MacAccess, number: Int) -> some View {
        let isDone = grant.done.contains(access)
        let isNow = access == grant.step
        return HStack(alignment: .top, spacing: SpotTokens.settingsGrantStepGap) {
            ZStack {
                Circle().fill(isDone ? SpotTheme.settingsDone : isNow ? Color.accentColor : Color.primary.opacity(SpotTheme.settingsStepFill))
                if isDone {
                    Image(systemName: "checkmark").font(SpotType.settingsTick).foregroundStyle(SpotTheme.settingsTileInk)
                } else {
                    Text("\(number)").font(SpotType.settingsNumber).foregroundStyle(isNow ? SpotTheme.settingsTileInk : Color.secondary)
                }
            }
            .frame(width: SpotTokens.settingsGrantStep, height: SpotTokens.settingsGrantStep)
            VStack(alignment: .leading, spacing: SpotTokens.settingsGroupGap) {
                VStack(alignment: .leading, spacing: SpotTokens.settingsDetailGap) {
                    Text(access.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(isNow ? Color.primary : Color.secondary)
                    if isNow {
                        Text(access.purpose)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if isNow {
                    systemSwitch(access.place)
                    if access.needsRestart {
                        Text("Openspot must start again to use it. Turn it on, then restart; Settings opens here again.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func systemSwitch(_ place: String) -> some View {
        VStack(alignment: .leading, spacing: SpotTokens.settingsUseGap) {
            HStack(spacing: SpotTokens.settingsRowGap) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: SpotTokens.settingsAppIcon, height: SpotTokens.settingsAppIcon)
                Text("Openspot")
                Spacer(minLength: SpotTokens.settingsTrailingGap)
                Toggle("", isOn: .constant(false))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                    .padding(SpotTokens.settingsSwitchInset)
                    .overlay(Capsule().strokeBorder(Color.accentColor, lineWidth: SpotTokens.settingsSwitchRing))
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, SpotTokens.settingsSwitchPadding)
            .frame(height: SpotTokens.settingsSwitchHeight)
            .background(Color.primary.opacity(SpotTheme.settingsQuietFill), in: SpotRoundShape(radius: SpotTokens.settingsSwitchCorner))
            Text("System Settings › \(place)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(SpotTokens.settingsSwitchFrame)
        .background(Color.primary.opacity(SpotTheme.settingsQuieterFill), in: SpotRoundShape(radius: SpotTokens.settingsCorner))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("In System Settings, \(place), turn on Openspot")
    }
}
