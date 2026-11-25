import OpenspotCore
import SwiftUI

extension SettingsView {
    func rowsPage(_ section: SettingsPage.Section) -> some View {
        Group {
            title(of: section)
            group(nil) { lines(book.rows.rows(in: section)) { settingLine($0) } }
        }
    }
}
