import Foundation

extension Manifest {
    public struct Action: Equatable, Sendable {
        static let table = "actions"
        static let keys: Set<String> = ["title", "icon", "confirm"]
        static let inputs = "inputs"
        static let outputs = "outputs"

        public let id: String
        public let title: String?
        public let icon: String?
        public let confirm: String?
        public let inputs: [Parameter]
        public let outputs: [Parameter]
        let section: String

        init(id: String, section: String, table: ConfigDocument.Table) throws {
            let fault = { (reason: String) in SpotError.fault("\(Manifest.fileName): \(section) \(reason)") }
            guard Setting.isKey(id) else { throw fault("needs an ID with no space, such as [actions.snooze].") }
            var texts: [String: String] = [:]
            var inputs: [Parameter] = []
            var outputs: [Parameter] = []
            for key in table.keys {
                let path = Manifest.path(key)
                if path.count == 2, path[0] == Self.inputs || path[0] == Self.outputs, Setting.isKey(path[1]) {
                    let parameter = try Parameter(name: path[1], value: table[key], keys: Parameter.inputKeys, place: "\(section) \(key)")
                    if path[0] == Self.inputs { inputs.append(parameter) } else { outputs.append(parameter) }
                } else if Self.keys.contains(key) {
                    guard case .string(let text)? = table[key] else { throw fault("takes a text in \(key).") }
                    texts[key] = text
                } else {
                    throw fault("has an unknown key: \(key). Use title, icon, confirm, inputs.<name> or outputs.<name>.")
                }
            }
            self.id = id
            self.section = section
            title = texts["title"]
            icon = texts["icon"]
            confirm = texts["confirm"]
            self.inputs = inputs
            self.outputs = outputs
        }

        var command: Command? {
            guard let title else { return nil }
            return Command(id: id, section: section, values: ["title": [title], "icon": icon.map { [$0] } ?? [], "confirm": confirm.map { [$0] } ?? []], written: [])
        }
    }
}
