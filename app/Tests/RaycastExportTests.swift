import CommonCrypto
import CryptoKit
import XCTest
@testable import OpenspotCore

final class RaycastExportTests: XCTestCase {
    private let payload: [String: Any] = [
        "quicklinks": [
            "openWithPlatforms": [["id": "plat-1", "macos": "/Applications/Safari.app"]],
            "quicklinks": [
                ["name": "Google Search", "link": "https://www.google.com/search?q={Query}"],
                ["name": "Downloads", "link": "~/Downloads", "openWith": "/System/Library/CoreServices/Finder.app"],
                ["name": "Docs", "link": "https://docs.example/{argument name=\"page\"}", "openWith": "plat-1"]
            ]
        ],
        "snippets": ["snippets": [
            ["title": "Email", "text": "hello@example.com", "keyword": ";mail"],
            ["title": "Signature", "text": "Best,\nTest User"]
        ]],
        "settings": ["commands": [
            ["id": "c:r:applications::*::application::=::/Applications/Safari.app", "macosHotkey": ["kind": [:]]],
            ["id": "c:r:calculator", "alias": "calc", "favoriteOrder": 0]
        ]],
        "clipboardHistory": ["clipboardEntries": [[:], [:]]]
    ]

    private func first(_ object: [String: Any], passphrase: String) throws -> Data {
        let key = Data(SHA256.hash(data: Data(passphrase.utf8)))
        let iv = Data((0..<16).map { UInt8($0 * 3) })
        let plain = try XCTUnwrap(Gzip.zip(try JSONSerialization.data(withJSONObject: object)))
        var out = Data(count: plain.count + 16)
        var written = 0
        let status = out.withUnsafeMutableBytes { out in
            key.withUnsafeBytes { key in
                iv.withUnsafeBytes { iv in
                    plain.withUnsafeBytes { plain in
                        CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                                key.baseAddress, key.count, iv.baseAddress, plain.baseAddress, plain.count, out.baseAddress, out.count, &written)
                    }
                }
            }
        }
        XCTAssertEqual(status, CCCryptorStatus(kCCSuccess))
        return iv + out.prefix(written)
    }

    func testAnExportOfRaycastTwoGivesItsQuicklinksSnippetsAndTheRest() throws {
        let export = try RaycastExport.read(try RaycastExport.file(payload, passphrase: "openspot-test"), passphrase: "openspot-test")

        XCTAssertEqual(export.quicklinks, [
            .init(title: "Google Search", url: "https://www.google.com/search?q={query}", app: nil),
            .init(title: "Downloads", url: "~/Downloads", app: "/System/Library/CoreServices/Finder.app"),
            .init(title: "Docs", url: "https://docs.example/{query}", app: "/Applications/Safari.app")
        ])
        XCTAssertEqual(export.snippets, [
            .init(title: "Email", text: "hello@example.com", keyword: ";mail"),
            .init(title: "Signature", text: "Best,\nTest User", keyword: nil)
        ])
        XCTAssertEqual(export.rest, RaycastExport.Rest(hotkeys: 1, aliases: 1, favorites: 1, clips: 2))
    }

    func testAWrongPassphraseIsToldApartFromAFileThatIsNotAnExport() throws {
        let file = try RaycastExport.file(payload, passphrase: "openspot-test")

        XCTAssertThrowsError(try RaycastExport.read(file, passphrase: "wrong-pass")) { XCTAssertTrue("\($0)".contains("passphrase"), "\($0)") }
        XCTAssertThrowsError(try RaycastExport.read(Data("hello".utf8), passphrase: "openspot-test")) { XCTAssertTrue("\($0)".contains("a Raycast export. Choose the .rayconfig"), "\($0)") }
        XCTAssertThrowsError(try RaycastExport.read(try RaycastExport.file(payload, passphrase: "x", schema: 2), passphrase: "x")) { XCTAssertTrue("\($0)".contains("schema 2"), "\($0)") }
    }

    func testAnExportOfRaycastOneGivesItsSnippets() throws {
        let old: [String: Any] = ["raycast_version": "1.79.1", "builtin_package_snippets": ["snippets": [["name": "Email", "text": "hello@example.com", "keyword": ";mail"]]]]

        let export = try RaycastExport.read(try first(old, passphrase: "12345678"), passphrase: "12345678")

        XCTAssertEqual(export.snippets, [.init(title: "Email", text: "hello@example.com", keyword: ";mail")])
        XCTAssertThrowsError(try RaycastExport.read(try first(old, passphrase: "12345678"), passphrase: "87654321")) { XCTAssertTrue("\($0)".contains("passphrase"), "\($0)") }
    }
}
