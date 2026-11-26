import OpenspotCore
import SwiftUI

enum SettingsTitle {
    case heading, header, hero

    init(page: SettingsPage, isSearching: Bool) {
        switch page {
        case _ where isSearching: self = .heading
        case .account: self = .hero
        case .access, .accessOf, .spotOf: self = .header
        default: self = .heading
        }
    }

    var reveal: CGFloat {
        switch self {
        case .heading: SpotTokens.settingsHeadingReveal
        case .header: SpotTokens.settingsTitleReveal
        case .hero: SpotTokens.settingsHeroReveal
        }
    }
}
