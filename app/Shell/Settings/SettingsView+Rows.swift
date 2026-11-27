import OpenspotCore
import SwiftUI

extension SettingsView {
    var needsYou: some View {
        let waiting = book.spots.waiting
        return Group {
            if !waiting.isEmpty {
                group(waiting.count == 1 ? "1 spot needs you" : "\(waiting.count) spots need you") {
                    lines(waiting) { standing in
                        row(open: .spotOf(standing.id)) {
                            SettingsSpotIcon(spot: standing.spot, side: SpotTokens.settingsRowTile)
                            titled(standing.title, standing.lack)
                            Spacer(minLength: SpotTokens.settingsTrailingGap)
                            fix(standing)
                        }
                    }
                }
            }
        }
    }

    func sectionPage(_ section: SettingsPage.Section, rowsTitle: String? = nil, @ViewBuilder top: () -> some View = { EmptyView() }) -> some View {
        Group {
            title(of: section)
            top()
            group(rowsTitle) { lines(book.rows.rows(in: section)) { settingLine($0) } }
        }
    }
}
