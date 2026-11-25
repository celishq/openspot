import OpenspotCore
import SwiftUI

struct SettingsTile: View {
    let symbol: String
    let color: Color
    let side: CGFloat

    init(symbol: String, color: Color, side: CGFloat) {
        self.symbol = symbol
        self.color = color
        self.side = side
    }

    init(access: MacAccess, side: CGFloat) {
        self.init(symbol: Self.symbol(of: access), color: SpotTheme.settings(access), side: side)
    }

    var body: some View {
        SpotRoundShape(radius: side * SpotTokens.settingsTileCorner)
            .fill(color.gradient)
            .frame(width: side, height: side)
            .overlay(Image(systemName: symbol).font(SpotType.settingsTile(side: side)).foregroundStyle(SpotTheme.settingsTileInk))
    }

    private static func symbol(of access: MacAccess) -> String {
        switch access {
        case .accessibility: "accessibility"
        case .automation: "gearshape.2.fill"
        case .screen: "rectangle.dashed.badge.record"
        case .calendars: "calendar"
        case .reminders: "list.bullet"
        case .camera: "camera.fill"
        case .microphone: "mic.fill"
        case .input: "keyboard.fill"
        case .helper: "cup.and.saucer.fill"
        }
    }
}
