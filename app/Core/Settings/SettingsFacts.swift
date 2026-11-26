import Foundation

public struct SettingsFacts: Sendable {
    let access: AccessFacts
    let spots: SpotStandings
    let keys: KeyMap
    let rows: SettingRows
    let looks: [ListedTheme]
    let account: AccountStatus?

    init(accesses: [AccessList.Entry], loaded: [SpotStanding], core: [SpotList.Choice], rows: [SettingRow], looks: [ListedTheme], account: AccountStatus?) {
        access = AccessFacts(accesses)
        spots = SpotStandings(loaded: loaded, core: core)
        keys = KeyMap(rows)
        self.rows = SettingRows(rows)
        self.looks = looks
        self.account = account
    }
}
