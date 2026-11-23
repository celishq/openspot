import Foundation

extension CallShape {
    static func listing(of spot: Spot) -> [String: Any] {
        let commands = UseCommand.all(for: spot.uses).filter { $0.use != nil }.map { command -> [String: Any] in
            ["name": command.words.joined(separator: " "), "description": command.about, "inputs": CommandSlot.schema(of: command.slots)]
        }
        return ["spot": spot.id, "actions": actions(of: spot).map(\.listing), "commands": commands]
    }

    private var listing: [String: Any] {
        var entry: [String: Any] = ["name": name, "inputs": Self.object(of: inputs), "outputs": Self.object(of: outputs)]
        if let title { entry["title"] = title }
        return entry
    }

    private static func object(of parameters: [Manifest.Parameter]) -> [String: Any] {
        var properties: [String: Any] = [:]
        for parameter in parameters {
            var base = parameter.type.schema(options: parameter.options)
            if let detail = parameter.detail { base["description"] = detail }
            if let defaultValue = parameter.defaultValue { base["default"] = defaultValue }
            properties[parameter.name] = parameter.type.isList ? ["type": "array", "items": base] : base
        }
        return ["type": "object", "properties": properties, "required": parameters.filter(\.isRequired).map(\.name)]
    }
}
