import Foundation

extension Manifest {
    public struct RowType: Equatable, Sendable {
        static let table = "types"

        public let name: String
        public let title: String
        public let match: String

        init(name: String, section: String, table: ConfigDocument.Table) throws {
            let fault = { (reason: String) in SpotError.fault("\(Manifest.fileName): \(section) \(reason)") }
            guard Setting.isKey(name), !name.contains(".") else { throw fault("needs a name with no space and no dot, such as [types.color].") }
            var texts: [String: String] = [:]
            for key in table.keys {
                guard key == "title" || key == "match" else { throw fault("has an unknown key: \(key). Use title and match.") }
                guard case .string(let text)? = table[key], !text.isEmpty else { throw fault("takes a text in \(key).") }
                texts[key] = text
            }
            guard let title = texts["title"], let match = texts["match"] else {
                throw fault("needs a title and a match, such as title = \"Color\" and match = \"^#[0-9a-fA-F]{6}$\".")
            }
            guard (try? NSRegularExpression(pattern: match)) != nil else { throw fault("has a match that is no regular expression: \(match)") }
            self.name = name
            self.title = title
            self.match = match
        }

        public func holds(_ text: String) -> Bool {
            text.range(of: match, options: .regularExpression) != nil
        }
    }
}
