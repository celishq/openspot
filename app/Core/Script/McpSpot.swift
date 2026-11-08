import Foundation

/// A spot whose file is an MCP server on stdio. It answers the calls of a script in Swift: its tools are actions, and its
/// resources are rows (F10). Each call starts the server, does `initialize`, sends one request and closes its input.
struct McpSpot: Sendable {
    private static let version = "2025-06-18"
    private static let reserved: Set<String> = ["read", "run", "open", "drop", "on", "off", "level"]

    let process: ScriptProcess
    let lines: AsyncThrowingStream<String, Error>

    /// Answers one call with the text a script would print.
    func answer(_ arguments: [String], input: String?) async throws -> String {
        defer { process.end() }
        var session = Session(process: process, lines: lines.makeAsyncIterator())
        _ = try await session.ask("initialize", [
            "protocolVersion": Self.version,
            "capabilities": [String: Any](),
            "clientInfo": ["name": "openspot", "version": "1"]
        ])
        session.tell("notifications/initialized")
        switch arguments.first {
        case "read":
            return try await rows(session: &session)
        case "open":
            let result = try await session.ask("resources/read", ["uri": arguments.dropFirst().first ?? ""])
            let contents = result["contents"] as? [[String: Any]] ?? []
            return toast(contents.compactMap { $0["text"] as? String }.joined(separator: "\n"))
        case let name?:
            let tools = try await session.ask("tools/list", [:])["tools"] as? [[String: Any]] ?? []
            guard let tool = tools.first(where: { $0["name"] as? String == name }) else { throw PluginError.failed(1, "This server has no tool called \(name).") }
            let properties = Self.properties(of: tool)
            if !properties.isEmpty, input?.isEmpty ?? true { return Self.form(tool, properties) }
            let values = input.flatMap { TextBlock.blocks(in: $0).first }
            var given: [String: Any] = [:]
            for (key, schema) in properties {
                guard let text = values?.value(key) else { continue }
                given[key] = Self.value(text, type: schema["type"] as? String)
            }
            let result = try await session.ask("tools/call", ["name": name, "arguments": given])
            let content = result["content"] as? [[String: Any]] ?? []
            let text = content.compactMap { $0["text"] as? String }.joined(separator: "\n")
            if result["isError"] as? Bool == true { throw PluginError.failed(1, text) }
            return toast(text)
        case nil:
            return ""
        }
    }

    private func rows(session: inout Session) async throws -> String {
        let tools = try await session.ask("tools/list", [:])["tools"] as? [[String: Any]] ?? []
        let resources = (try? await session.ask("resources/list", [:]))?["resources"] as? [[String: Any]] ?? []
        var blocks: [TextBlock] = []
        for tool in tools {
            guard let name = tool["name"] as? String, !Self.reserved.contains(name) else { continue }
            var fields: [TextBlock.Field] = [
                .init(key: "action", value: name),
                .init(key: "title", value: tool["title"] as? String ?? name),
                .init(key: "scope", value: "command")
            ]
            if !Self.properties(of: tool).isEmpty { fields.append(.init(key: "form", value: "true")) }
            blocks.append(TextBlock(fields: fields))
        }
        for resource in resources {
            guard let uri = resource["uri"] as? String else { continue }
            var fields: [TextBlock.Field] = [.init(key: "row", value: resource["title"] as? String ?? resource["name"] as? String ?? uri)]
            if let detail = resource["description"] as? String { fields.append(.init(key: "detail", value: detail)) }
            fields.append(.init(key: "run", value: uri))
            blocks.append(TextBlock(fields: fields))
        }
        return blocks.map(\.text).joined(separator: "\n")
    }

    private func toast(_ text: String) -> String {
        text.isEmpty ? "" : TextBlock(fields: [.init(key: "toast", value: text)]).text
    }

    /// The properties of the input of a tool, in the order of its schema, with the required ones first.
    private static func properties(of tool: [String: Any]) -> [(String, [String: Any])] {
        let schema = tool["inputSchema"] as? [String: Any]
        let properties = schema?["properties"] as? [String: [String: Any]] ?? [:]
        let required = schema?["required"] as? [String] ?? []
        return properties.map { ($0.key, $0.value) }.sorted { (required.contains($0.0) ? 0 : 1, $0.0) < (required.contains($1.0) ? 0 : 1, $1.0) }
    }

    private static func form(_ tool: [String: Any], _ properties: [(String, [String: Any])]) -> String {
        let required = (tool["inputSchema"] as? [String: Any])?["required"] as? [String] ?? []
        var blocks = [TextBlock(fields: [.init(key: "title", value: tool["title"] as? String ?? tool["name"] as? String ?? "")])]
        for (key, schema) in properties {
            var fields: [TextBlock.Field] = [.init(key: "field", value: key), .init(key: "label", value: schema["title"] as? String ?? key)]
            if required.contains(key) { fields.append(.init(key: "required", value: "true")) }
            if let detail = schema["description"] as? String { fields.append(.init(key: "placeholder", value: detail)) }
            blocks.append(TextBlock(fields: fields))
        }
        return blocks.map(\.text).joined(separator: "\n")
    }

    private static func value(_ text: String, type: String?) -> Any {
        switch type {
        case "integer": Int(text) ?? text
        case "number": Double(text) ?? text
        case "boolean": text == "true"
        default: text
        }
    }

    /// One JSON-RPC exchange over the lines of the server.
    private struct Session {
        let process: ScriptProcess
        var lines: AsyncThrowingStream<String, Error>.AsyncIterator
        var count = 0

        mutating func ask(_ method: String, _ parameters: [String: Any]) async throws -> [String: Any] {
            count += 1
            let id = count
            send(["jsonrpc": "2.0", "id": id, "method": method, "params": parameters])
            while let line = try await lines.next() {
                guard let data = line.data(using: .utf8),
                      let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      message["id"] as? Int == id else { continue }
                if let error = message["error"] as? [String: Any] {
                    throw PluginError.failed(1, error["message"] as? String ?? "The server refused \(method).")
                }
                return message["result"] as? [String: Any] ?? [:]
            }
            throw PluginError.failed(1, "The server ended before it answered \(method).")
        }

        func tell(_ method: String) {
            send(["jsonrpc": "2.0", "method": method])
        }

        private func send(_ message: [String: Any]) {
            guard let data = try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys, .withoutEscapingSlashes]) else { return }
            process.send(text: String(decoding: data, as: UTF8.self) + "\n")
        }
    }
}
