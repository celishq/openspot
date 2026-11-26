import Foundation

extension SpotItem {
    func handedValue() -> AttachmentValue? {
        let value = { (key: String) in fields.first { $0.key == key && !$0.value.isEmpty }?.value }
        if let url = value("url") { return AttachmentValue(url: url, title: title) }
        if let text = value("text") { return AttachmentValue(text: text, title: title) }
        if let file { return AttachmentValue(files: FileKinds([file], kinds: [file: .file]), title: title) }
        return nil
    }
}
