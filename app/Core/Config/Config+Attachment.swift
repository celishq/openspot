import Foundation

extension Config {
    func hidesAttachment(of spot: String) -> Bool {
        setting(ReservedSetting.attachment, of: spot) == ReservedSetting.hiddenAttachment
    }
}
