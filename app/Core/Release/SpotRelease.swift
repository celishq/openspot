import CryptoKit
import Foundation

/// One signed release of a spot: a nostr event (NIP-01) of kind 30063, the release artifact set of NIP-51. Its `d` tag is
/// `<address>@<version>`, a `file` tag names each file with its SHA-256, its size and its mode, an `e` tag marked `previous`
/// names the release before it, and its content is the readme.
public struct SpotRelease: Equatable, Sendable {
    public static let kind = 30063
    /// The marker of the `e` tag that names the release before this one.
    static let previousMarker = "previous"

    public let id: String
    public let publicKey: String
    public let createdAt: Int
    public let kind: Int
    public let tags: [[String]]
    public let content: String
    public let signature: String

    /// Signs a release of these files.
    public static func sign(
        _ files: [SpotPackage.File],
        address: String,
        version: Int,
        previous: String?,
        readme: String,
        by key: AccountKey,
        at date: Date = Date()
    ) throws -> SpotRelease {
        var tags: [[String]] = [["d", "\(address)@\(version)"]]
        if let previous { tags.append(["e", previous, "", previousMarker]) }
        for file in SpotManifest(files).sorted {
            tags.append(["file", file.path, file.sha256, String(file.size), file.isExecutable ? "755" : "644"])
        }
        let createdAt = Int(date.timeIntervalSince1970)
        let digest = Self.digest(publicKey: key.publicKey, createdAt: createdAt, kind: kind, tags: tags, content: readme)
        return SpotRelease(
            id: digest.hex, publicKey: key.publicKey, createdAt: createdAt, kind: kind, tags: tags, content: readme,
            signature: try key.sign(digest).hex
        )
    }

    /// Reads one line of `releases.jsonl`. Throws a fault for a line that is not an event.
    public init(line: String) throws {
        guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
              let id = object["id"] as? String, let publicKey = object["pubkey"] as? String,
              let createdAt = object["created_at"] as? Int, let kind = object["kind"] as? Int,
              let tags = object["tags"] as? [[String]], let content = object["content"] as? String,
              let signature = object["sig"] as? String
        else { throw SpotError.fault("A line of releases.jsonl is not a nostr event.") }
        self.init(id: id, publicKey: publicKey, createdAt: createdAt, kind: kind, tags: tags, content: content, signature: signature)
    }

    init(id: String, publicKey: String, createdAt: Int, kind: Int, tags: [[String]], content: String, signature: String) {
        self.id = id
        self.publicKey = publicKey
        self.createdAt = createdAt
        self.kind = kind
        self.tags = tags
        self.content = content
        self.signature = signature
    }

    /// Whether its id is the hash of what it holds, and its signature is its author's over that id.
    public var isAuthentic: Bool {
        let digest = Self.digest(publicKey: publicKey, createdAt: createdAt, kind: kind, tags: tags, content: content)
        guard digest.hex == id, let signature = Data(hex: signature) else { return false }
        return AccountKey.isValid(signature, of: digest, by: publicKey)
    }

    /// The address of the spot, the same for each of its versions.
    public var address: String? {
        place?.address
    }

    public var version: Int? {
        place?.version
    }

    /// The id of the release before this one.
    public var previous: String? {
        tags.first { $0.count >= 4 && $0[0] == "e" && $0[3] == Self.previousMarker }?[1]
    }

    /// The manifest of the files that it names. Throws a fault for a `file` tag that cannot be read.
    public func manifest() throws -> SpotManifest {
        SpotManifest(try tags.filter { $0.first == "file" }.map { tag in
            guard tag.count >= 5, let size = Int(tag[3]), ["755", "644"].contains(tag[4]) else {
                throw SpotError.fault("A release names a file that Openspot cannot read.")
            }
            return SpotManifest.File(path: tag[1], sha256: tag[2], size: size, isExecutable: tag[4] == "755")
        })
    }

    /// Its line in `releases.jsonl`: the event as one line of JSON.
    public var line: String {
        let fields = [
            "\"id\":\(Self.quoted(id))", "\"pubkey\":\(Self.quoted(publicKey))", "\"created_at\":\(createdAt)", "\"kind\":\(kind)",
            "\"tags\":\(Self.json(tags))", "\"content\":\(Self.quoted(content))", "\"sig\":\(Self.quoted(signature))"
        ]
        return "{" + fields.joined(separator: ",") + "}"
    }

    /// The address and the version that its `d` tag holds.
    private var place: (address: String, version: Int)? {
        guard let value = tags.first(where: { $0.count >= 2 && $0[0] == "d" })?[1], let at = value.lastIndex(of: "@"),
              let version = Int(value[value.index(after: at)...]) else { return nil }
        return (String(value[..<at]), version)
    }

    /// The SHA-256 of the NIP-01 serialization: `[0,pubkey,created_at,kind,tags,content]` with no spaces.
    static func digest(publicKey: String, createdAt: Int, kind: Int, tags: [[String]], content: String) -> Data {
        let text = "[0,\(quoted(publicKey)),\(createdAt),\(kind),\(json(tags)),\(quoted(content))]"
        return Data(CryptoKit.SHA256.hash(data: Data(text.utf8)))
    }

    private static func json(_ tags: [[String]]) -> String {
        "[" + tags.map { "[" + $0.map(quoted).joined(separator: ",") + "]" }.joined(separator: ",") + "]"
    }

    /// A JSON string as NIP-01 writes it: only the quote, the backslash and the control characters are escaped.
    static func quoted(_ text: String) -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case "\u{08}": result += "\\b"
            case "\u{0C}": result += "\\f"
            case _ where scalar.value < 0x20: result += String(format: "\\u%04x", scalar.value)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }
}
