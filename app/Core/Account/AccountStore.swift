import Foundation
import Security

/// Where the account key lives: an item of the Keychain in a release build, or a file `account` with mode 0600 in the
/// state folder when `OPENSPOT_CONFIG` or a Debug build names one, so that a test or a build under work never touches the
/// Keychain. It holds the 12 words, or the `nsec` of a key that has none.
public struct AccountStore: Sendable {
    private static let service = "dev.openspot.account"
    private static let account = "key"
    private static let fileName = "account"

    /// The file that holds the key, or nil for the Keychain.
    let file: URL?

    init(file: URL?) {
        self.file = file
    }

    public static func standard(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        devState: String? = Bundle.main.object(forInfoDictionaryKey: "OpenspotDevState") as? String
    ) -> AccountStore {
        let isOwnState = [environment["OPENSPOT_CONFIG"], devState].contains { $0?.isEmpty == false }
        let folder = SpotFolder.config(environment: environment, home: home, devState: devState)
        return AccountStore(file: isOwnState ? folder.appendingPathComponent(fileName) : nil)
    }

    /// The key that it holds, or nil when it holds none.
    public func key() throws -> AccountKey? {
        guard let text = try read()?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text.hasPrefix("nsec") ? try AccountKey(nsec: text) : try AccountKey(words: text.split(separator: " ").map(String.init))
    }

    /// The key that it holds, made and kept at the first need.
    public func keyMadeOnce() throws -> AccountKey {
        if let key = try key() { return key }
        let key = try AccountKey.make()
        try keep(key)
        return key
    }

    /// Keeps a key in place of the one it holds.
    public func keep(_ key: AccountKey) throws {
        try write(key.words?.joined(separator: " ") ?? key.nsec)
    }

    private func read() throws -> String? {
        if let file {
            return try? String(contentsOf: file, encoding: .utf8)
        }
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query(adding: [kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]) as CFDictionary, &result)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw Self.fault(status) }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ text: String) throws {
        if let file {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions: 0o600])
            try Data(text.utf8).write(to: file)
            return
        }
        let data = Data(text.utf8)
        var status = SecItemUpdate(query() as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query(adding: [kSecValueData: data, kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock]) as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw Self.fault(status) }
    }

    private func query(adding more: [CFString: Any] = [:]) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: Self.service, kSecAttrAccount: Self.account].merging(more) { _, new in new }
    }

    private static func fault(_ status: OSStatus) -> SpotError {
        .fault("Openspot cannot reach your account key in the Keychain. \(SecCopyErrorMessageString(status, nil) as String? ?? "Error \(status).")")
    }
}
