import CryptoKit
import XCTest
@testable import OpenspotCore

extension RaycastExport {
    static var testPayload: [String: Any] { [
        "quicklinks": ["quicklinks": [
            ["name": "Google Search", "link": "https://www.google.com/search?q={Query}"],
            ["name": "Downloads", "link": "~/Downloads"]
        ]],
        "snippets": ["snippets": [["title": "Email", "text": "hello@example.com", "keyword": ";mail"]]],
        "settings": ["commands": [["id": "c:r:calculator", "alias": "calc", "macosHotkey": ["kind": [:]]]]]
    ] }

    static func file(_ object: [String: Any], passphrase: String, schema: Int = 3) throws -> Data {
        let salt = Data((0..<16).map { UInt8($0) })
        let iv = Data((0..<16).map { UInt8(200 - $0) })
        let hex = { (data: Data) in data.map { String(format: "%02x", $0) }.joined() }
        let head = try JSONSerialization.data(withJSONObject: ["appVersion": "2.0.5.0", "schemaVersion": schema, "encryption": ["iv": hex(iv), "salt": hex(salt)]])
        let header = try XCTUnwrap(Gzip.zip(head))
        let key = try XCTUnwrap(Scrypt.key(password: Data(passphrase.utf8), salt: salt, cost: 16384, blockSize: 8, parallel: 1, length: 32))
        let body = try XCTUnwrap(Gzip.zip(try JSONSerialization.data(withJSONObject: object)))
        let box = try AES.GCM.seal(body, using: SymmetricKey(data: key), nonce: try AES.GCM.Nonce(data: iv))
        var file = Data("RAYCFG3\n".utf8)
        withUnsafeBytes(of: UInt32(header.count).littleEndian) { file.append(contentsOf: $0) }
        return file + header + box.ciphertext + box.tag
    }
}
