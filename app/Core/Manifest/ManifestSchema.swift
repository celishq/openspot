import Foundation

public enum ManifestSchema {
    public static let repoPath = "schema/spot.schema.json"
    static let scripts = "scripts"

    public static var text: String {
        json(document)
    }

    static func json(_ value: Any) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    private static var document: [String: Any] {
        var schema = spot
        schema["$schema"] = "https://json-schema.org/draft/2020-12/schema"
        schema["title"] = Manifest.fileName
        schema["$defs"] = definitions
        return schema
    }

    private static var spot: [String: Any] {
        var properties: [String: Any] = [:]
        for key in Manifest.keys { properties[key] = reference("texts") }
        properties["stay"] = ["type": "boolean"]
        properties[Manifest.Setting.table] = table(["anyOf": [reference("type"), reference("setting")]])
        properties[Manifest.Action.table] = table(reference("action"))
        properties[Manifest.Command.table] = table(reference("command"))
        properties[scripts] = table(reference("script"))
        return ["type": "object", "additionalProperties": false, "properties": properties]
    }

    private static var definitions: [String: Any] {
        var script = spot
        var scriptProperties = script["properties"] as? [String: Any] ?? [:]
        scriptProperties[scripts] = nil
        script["properties"] = scriptProperties
        let names = ValueType.Kind.allCases.flatMap { [ValueType($0).name, ValueType($0, isList: true).name] }
        let value: [String: Any] = ["type": ["string", "number", "boolean"]]
        let fields: [String: [String: Any]] = [
            "type": reference("type"), "required": ["type": "boolean"], "default": value, "description": ["type": "string"],
            "options": ["type": "array", "items": ["type": "string"]], "title": ["type": "string"], "icon": ["type": "string"], "confirm": ["type": "string"]
        ]
        let settingKeys = Manifest.Parameter.settingKeys.union(Manifest.Setting.keys)
        let parameter: [String: Any] = ["anyOf": [reference("type"), object(Manifest.Parameter.inputKeys, from: fields, required: ["type"])]]
        var action = object(Manifest.Action.keys, from: fields)
        var actionProperties = action["properties"] as? [String: Any] ?? [:]
        actionProperties[Manifest.Action.inputs] = table(reference("parameter"))
        actionProperties[Manifest.Action.outputs] = table(reference("parameter"))
        action["properties"] = actionProperties
        return [
            "texts": ["anyOf": [["type": "string"], ["type": "array", "items": ["type": "string"]]]],
            "type": ["enum": names],
            "setting": object(settingKeys, from: fields),
            "parameter": parameter,
            "action": action,
            "command": object(Manifest.Command.keys, from: [:]),
            "script": script
        ]
    }

    static func actions(of spot: Spot) -> [String: Any] {
        let actions = spot.typedActions.map { action -> [String: Any] in
            var entry: [String: Any] = ["name": action.id, "inputs": object(of: action.inputs), "outputs": object(of: action.outputs)]
            if let title = action.title { entry["title"] = title }
            return entry
        }
        let commands = CommandNoun.all.flatMap { noun in
            noun.shown.filter { $0.rule.use.map(spot.uses.contains) == true }.map { verb -> [String: Any] in
                ["name": ([noun.name] + verb.words).joined(separator: " "), "description": verb.about, "inputs": verb.inputs]
            }
        }
        return ["spot": spot.id, "actions": actions, "commands": commands]
    }

    static func object(of parameters: [Manifest.Parameter]) -> [String: Any] {
        var properties: [String: Any] = [:]
        for parameter in parameters {
            var base: [String: Any] = switch parameter.type.kind {
            case .text, .secret: ["type": "string"]
            case .number: ["type": "number"]
            case .bool: ["type": "boolean"]
            case .date: ["type": "string", "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}"]
            case .duration: ["type": "number", "minimum": 0]
            case .url: ["type": "string", "format": "uri"]
            case .file: ["type": "string", "pattern": "^/"]
            case .choice: ["enum": parameter.options]
            }
            if let detail = parameter.detail { base["description"] = detail }
            if let defaultValue = parameter.defaultValue { base["default"] = defaultValue }
            properties[parameter.name] = parameter.type.isList ? ["type": "array", "items": base] : base
        }
        return ["type": "object", "properties": properties, "required": parameters.filter(\.isRequired).map(\.name)]
    }

    private static func object(_ keys: Set<String>, from fields: [String: [String: Any]], required: [String] = []) -> [String: Any] {
        var properties: [String: Any] = [:]
        for key in keys { properties[key] = fields[key] ?? reference("texts") }
        var object: [String: Any] = ["type": "object", "additionalProperties": false, "properties": properties]
        if !required.isEmpty { object["required"] = required }
        return object
    }

    private static func table(_ value: [String: Any]) -> [String: Any] {
        ["type": "object", "additionalProperties": value]
    }

    private static func reference(_ name: String) -> [String: Any] {
        ["$ref": "#/$defs/\(name)"]
    }
}
