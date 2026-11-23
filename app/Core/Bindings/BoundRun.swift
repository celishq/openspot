import Foundation

struct BoundRun: Sendable {
    let binding: Manifest.Binding
    let action: String
    let inputs: [TextBlock.Field]
    let out: String?
    let stdin: (name: String, read: @Sendable () async -> String)?

    var name: String {
        "\(binding.name).\(action)"
    }

    func given() async -> [TextBlock.Field] {
        guard let stdin else { return inputs }
        let text = await stdin.read()
        return inputs + [.init(key: stdin.name, value: text.hasSuffix("\n") ? String(text.dropLast()) : text)]
    }
}
