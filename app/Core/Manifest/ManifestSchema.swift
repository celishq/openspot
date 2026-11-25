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
        properties[Manifest.Triggers.table] = reference("on")
        properties[Manifest.Setting.table] = table(["anyOf": [reference("type"), reference("setting")]])
        properties[Manifest.Action.table] = table(reference("action"))
        properties[Manifest.Binding.table] = table(reference("binding"))
        properties[Manifest.Event.table] = table(table(reference("parameter")))
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
            "options": ["type": "array", "items": ["type": "string"]], "pattern": ["type": "string"], "title": ["type": "string"], "icon": ["type": "string"], "confirm": ["type": "string"],
            "offers": ["type": "array", "items": ["type": "string"]], "shortcut": ["type": "string"], "close": ["type": "boolean"], "when": ["type": "string"]
        ]
        let settingKeys = Manifest.Parameter.settingKeys
        let parameter: [String: Any] = ["anyOf": [reference("type"), object(Manifest.Parameter.inputKeys, from: fields, required: ["type"])]]
        var action = object(Manifest.Action.keys.union(Manifest.Action.appKeys), from: fields)
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
            "binding": object([Manifest.Binding.spotKey], from: [Manifest.Binding.spotKey: ["type": "string"]], required: [Manifest.Binding.spotKey]),
            "on": triggers,
            "script": script
        ]
    }

    private static var triggers: [String: Any] {
        let words: [String: Any] = ["type": "array", "items": ["type": "string"]]
        let properties: [String: Any] = [
            Manifest.Triggers.command: words, Manifest.Triggers.search: ["type": ["boolean", "string"]], Manifest.Triggers.schedule: words,
            Manifest.Triggers.every: ["type": "integer", "minimum": 1], Manifest.Triggers.drop: words, Manifest.Triggers.pick: ["type": "string"]
        ]
        return ["type": "object", "properties": properties, "additionalProperties": ["type": ["boolean", "string"]]]
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
