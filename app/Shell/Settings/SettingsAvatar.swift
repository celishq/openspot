import OpenspotCore
import SwiftUI

struct SettingsAvatar: View {
    let side: CGFloat

    var body: some View {
        Circle()
            .fill(SpotTheme.settingsAccountTile.gradient)
            .frame(width: side, height: side)
            .overlay(Image(systemName: "person.fill").font(SpotType.settingsTile(side: side)).foregroundStyle(SpotTheme.settingsTileInk))
    }
}
