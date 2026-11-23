import Foundation

extension SpotRuns {
    func fill(_ name: String, of id: String) {
        guard let sheet = sheets[id] else { return }
        let handler = Manifest.Triggers.cache + "." + name
        let key = "\(Manifest.Triggers.table).\(handler)"
        guard sheet.running(key) == nil else { return }
        sheet.trigger(Message(handler), key: key)
    }

    func cacheChanged(_ id: String) {
        guard let sheet = sheets[id], !sheet.answerQuery.isEmpty else { return }
        sheet.askAnswer()
    }
}
