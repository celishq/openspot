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

    func topic(_ name: String) -> GuideTopic? {
        topics.first { $0.slug == name.lowercased() || $0.title.lowercased() == name.lowercased() }
    }
}
