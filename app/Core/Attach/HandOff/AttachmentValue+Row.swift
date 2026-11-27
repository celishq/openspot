import Foundation

extension AttachmentValue {
    init?(row item: SpotItem) {
        let value = { (key: String) in item.fields.first { $0.key == key && !$0.value.isEmpty }?.value }
        if let url = value("url") {
            self.init(url: url, title: item.title)
        } else if let text = value("text") {
            self.init(text: text, title: item.title)
        } else if let file = item.file {
            self.init(files: FileKinds([file], kinds: [file: .file]), title: item.title)
        } else {
            return nil
        }
    }
}
