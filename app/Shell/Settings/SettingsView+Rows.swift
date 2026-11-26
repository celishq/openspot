import OpenspotCore
import SwiftUI

extension SettingsView {
    var generalPage: some View {
        let waiting = book.spots.waiting
        return Group {
            title(of: .general)
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
            group("Openspot") { lines(book.rows.rows(in: .general)) { settingLine($0) } }
        }
    }

    func rowsPage(_ section: SettingsPage.Section) -> some View {
        Group {
            title(of: section)
            group(nil) { lines(book.rows.rows(in: section)) { settingLine($0) } }
        }
    }
}
