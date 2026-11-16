import Foundation

struct Guide: Sendable {
    let text: String
    let topics: [GuideTopic]

    init(text: String, pages: [String: String]) {
        self.text = text
        topics = GuideTopic.all(in: text) + pages.sorted { $0.key < $1.key }.map { name, page in
            let head = page.split(separator: "\n").first.map { String($0.drop { $0 == "#" || $0 == " " }) } ?? name
            return GuideTopic(slug: name, title: head, text: page)
        }
    }

    static func read(from mac: Mac) throws -> Guide {
        guard let file = mac.guide else { throw SpotError.fault("This copy of Openspot has no guide. Install Openspot again.") }
        let names = mac.pages.flatMap { try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) } ?? []
        let pages = try Dictionary(uniqueKeysWithValues: names.filter { $0.pathExtension == "md" }.map { ($0.deletingPathExtension().lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) })
        return Guide(text: try String(contentsOf: file, encoding: .utf8), pages: pages)
    }

    func topic(_ name: String) -> GuideTopic? {
        topics.first { $0.slug == name.lowercased() || $0.title.lowercased() == name.lowercased() }
    }
}
