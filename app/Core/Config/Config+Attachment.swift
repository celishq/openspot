import Foundation

extension Config {
    func hidesAttachment(of spot: String) -> Bool {
        setting(SpotPlace.searchField.key, of: spot) == ReservedSetting.hiddenAttachment
    }
}
