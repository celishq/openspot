import Foundation

extension Manifest {
    public struct Action: Equatable, Sendable {
        static let table = "actions"
        static let keys: Set<String> = ["title", "icon", "confirm"]
        static let appKeys: Set<String> = ["offers", "shortcut", "close", ActionHook.when.rawValue]
        static let inputs = "inputs"
        static let outputs = "outputs"

        public let id: String
        public let title: String?
        public let icon: String?
        public let confirm: String?
        public let inputs: [Parameter]
        public let outputs: [Parameter]
        public let offers: [String]
        let shortcut: String?
        let close: Bool?
        let hooks: [ActionHook: String]
        let section: String
        let appKey: String?

        init(id: String, section: String, table: ConfigDocument.Table) throws {
            let fault = { (reason: String) in SpotError.fault("\(Manifest.fileName): \(section) \(reason)") }
            guard Setting.isKey(id) else { throw fault("needs an ID with no space, such as [actions.snooze].") }
            var texts: [String: String] = [:]
            var inputs: [Parameter] = []
            var outputs: [Parameter] = []
            var appValues: [String: [String]] = [:]
            var appKey: String?
            for key in table.keys {
                let path = Manifest.path(key)
                if path.count == 2, path[0] == Self.inputs || path[0] == Self.outputs, Setting.isKey(path[1]) {
                    let parameter = try Parameter(name: path[1], value: table[key], keys: Parameter.inputKeys, place: "\(section) \(key)")
                    if path[0] == Self.inputs { inputs.append(parameter) } else { outputs.append(parameter) }
                } else if Self.appKeys.contains(key) {
                    switch table[key] {
                    case .string(let text): appValues[key] = [text]
                    case .boolean(let isOn): appValues[key] = [String(isOn)]
                    case .strings(let texts): appValues[key] = texts
                    default: throw fault("takes a text in \(key).")
                    }
                    appKey = appKey ?? key
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
            offers = appValues["offers"] ?? []
            shortcut = appValues["shortcut"]?.first
            close = appValues["close"]?.first.flatMap(Bool.init)
            hooks = ActionHook.allCases.reduce(into: [:]) { hooks, hook in hooks[hook] = appValues[hook.rawValue]?.first }
            self.appKey = appKey
        }

        public var closes: Bool {
            close != false
        }
    }
}

extension Manifest.Action {
    var check: Manifest.InputCheck {
        Manifest.InputCheck(owner: id, kind: .input, parameters: inputs)
    }

    func fault(in outputs: [TextBlock.Field]) -> String? {
        if let unknown = outputs.first(where: { output in !self.outputs.contains { $0.name == output.key } }) {
            return "\(id) gave out.\(unknown.key), which its outputs do not hold"
        }
        for output in self.outputs {
            let values = outputs.filter { $0.key == output.name }.map(\.value)
            if values.isEmpty, output.isRequired { return "\(id) gave no out.\(output.name)" }
            if !values.isEmpty, let fault = output.fault(in: values) { return "\(id) gave a wrong out.\(output.name): \(fault)" }
        }
        return nil
    }
}

extension Manifest.Action {
    public var lacksInput: Bool {
        inputs.contains { $0.isRequired && $0.defaultValue == nil }
    }

    public var textInput: Manifest.Parameter? {
        let texts = inputs.filter { $0.type.kind == .text && !$0.type.isList }
        return texts.first { $0.isRequired } ?? texts.first
    }

    public func itemForm(values: [String: String] = [:], title: String? = nil) -> ItemForm {
        ItemForm(title: title ?? self.title ?? id, fields: inputs.map { $0.formField(value: values[$0.name]) })
    }
}

extension Manifest.Parameter {
    func formField(value: String?) -> ItemForm.Field {
        let defaultValue = value ?? defaultValue
        let label = title ?? name.prefix(1).uppercased() + name.dropFirst()
        switch type.kind {
        case .bool:
            return ItemForm.Field(name: name, label: label, type: .switch, value: Bool(defaultValue ?? "") == true ? "true" : "false")
        case .choice:
            let options = options.map { SpotPart.Option(id: $0, title: $0) }
            return ItemForm.Field(name: name, label: label, type: .choice, value: defaultValue ?? options.first?.id, options: options)
        default:
            return ItemForm.Field(name: name, label: label, value: defaultValue, required: isRequired ? true : nil, placeholder: detail)
        }
    }
}
