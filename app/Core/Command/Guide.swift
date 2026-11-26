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
        let name = name.lowercased()
        guard let slash = name.firstIndex(of: "/") else { return topics.first { $0.slug == name || $0.title.lowercased() == name } }
        return topic(String(name[..<slash]))?.sections.first { $0.slug == name }
    }

    var addresses: [String] {
        topics.flatMap { [$0.slug] + $0.sections.map(\.slug) }
    }
}
