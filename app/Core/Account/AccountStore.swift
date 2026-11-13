import Foundation
import Security

/// Where the account key lives: an item of the Keychain in a release build, or a file `account` with mode 0600 in the
/// state folder when `OPENSPOT_CONFIG` or a Debug build names one, so that a test or a build under work never touches the
/// Keychain. It holds the 12 words, or the `nsec` of a key that has none, then a line `backed-up` once the person has
/// the words. The Keychain item syncs through iCloud Keychain when the app has its Keychain group, and else stays in the
/// login Keychain of this Mac.
public struct AccountStore: Sendable {
    private static let service = "dev.openspot.account"
    private static let account = "key"
    private static let fileName = "account"
    private static let backedUpLine = "backed-up"

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
        let folder = SpotsFolder.config(environment: environment, home: home, devState: devState)
        return AccountStore(file: isOwnState ? folder.appendingPathComponent(fileName) : nil)
    }

    /// The key that it holds, or nil when it holds none.
    public func key() throws -> AccountKey? {
        guard let line = try lines()?.first, !line.isEmpty else { return nil }
        return line.hasPrefix("nsec") ? try AccountKey(nsec: line) : try AccountKey(words: line.split(separator: " ").map(String.init))
    }

    /// The key that it holds, made and kept at the first need.
    public func keyMadeOnce() throws -> AccountKey {
        if let key = try key() { return key }
        let key = try AccountKey.make()
        try keep(key)
        return key
    }

    /// Keeps a key in place of the one it holds, marked as backed up when the person already has its words.
    public func keep(_ key: AccountKey, isBackedUp: Bool = false) throws {
        try write([key.words?.joined(separator: " ") ?? key.nsec] + (isBackedUp ? [Self.backedUpLine] : []))
    }

    /// Whether the person has the words of the key that it holds.
    public func isBackedUp() throws -> Bool {
        try lines()?.dropFirst().contains(Self.backedUpLine) == true
    }

    public func markBackedUp() throws {
        guard let key = try key() else { return }
        try keep(key, isBackedUp: true)
    }

    /// Removes the key, from every Mac that syncs it too.
    public func remove() throws {
        if let file {
            guard FileManager.default.fileExists(atPath: file.path) else { return }
            return try FileManager.default.removeItem(at: file)
        }
        let status = SecItemDelete(query(in: keychain) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Self.fault(status) }
    }

    /// Whether this copy of the app can sync the key through iCloud Keychain.
    public var canSync: Bool {
        file == nil && keychain == .synced
    }

    /// Whether the key that it holds syncs through iCloud Keychain.
    public func isSyncing() throws -> Bool {
        guard canSync else { return false }
        return try item()?.isSynced == true
    }

    /// Makes the key that it holds sync through iCloud Keychain, or stay on this Mac, which removes it from the other Macs.
    public func setSyncing(_ isOn: Bool) throws {
        guard canSync else { throw SpotError.fault("This copy of Openspot keeps your account on this Mac only.") }
        guard let item = try item(), item.isSynced != isOn else { return }
        try add(item.data, in: .synced, syncing: isOn)
        let status = SecItemDelete(query(in: .synced, adding: [kSecAttrSynchronizable: item.isSynced]) as CFDictionary)
        guard status == errSecSuccess else { throw Self.fault(status) }
    }

    /// The Keychain that holds items of the app: the data-protection one when the app has its Keychain group, else the
    /// login Keychain.
    private enum Keychain {
        case synced, login
    }

    /// A read of the data-protection Keychain finds nothing in an app with no Keychain group, and only a write or a delete
    /// says that the group is missing, so the gate deletes an item that is never kept.
    private var keychain: Keychain {
        let probe: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword, kSecAttrService: Self.service + ".probe", kSecUseDataProtectionKeychain: true,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ]
        return SecItemDelete(probe as CFDictionary) == errSecMissingEntitlement ? .login : .synced
    }

    private func lines() throws -> [String]? {
        let text: String?
        if let file {
            text = try? String(contentsOf: file, encoding: .utf8)
        } else {
            text = try item().map { String(decoding: $0.data, as: UTF8.self) }
        }
        return text?.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func write(_ lines: [String]) throws {
        let text = lines.joined(separator: "\n")
        if let file {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions: 0o600])
            try Data(text.utf8).write(to: file)
            return
        }
        let data = Data(text.utf8)
        let place = keychain
        let status = SecItemUpdate(query(in: place) as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound { return try add(data, in: place, syncing: place == .synced) }
        guard status == errSecSuccess else { throw Self.fault(status) }
    }

    private func item() throws -> (data: Data, isSynced: Bool)? {
        var result: CFTypeRef?
        let more: [CFString: Any] = [kSecReturnData: true, kSecReturnAttributes: true, kSecMatchLimit: kSecMatchLimitOne]
        let status = SecItemCopyMatching(query(in: keychain, adding: more) as CFDictionary, &result)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess, let found = result as? [CFString: Any], let data = found[kSecValueData] as? Data else { throw Self.fault(status) }
        return (data, (found[kSecAttrSynchronizable] as? Bool) ?? ((found[kSecAttrSynchronizable] as? NSNumber)?.boolValue ?? false))
    }

    private func add(_ data: Data, in place: Keychain, syncing: Bool) throws {
        var more: [CFString: Any] = [kSecValueData: data, kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock]
        if place == .synced { more[kSecAttrSynchronizable] = syncing }
        let status = SecItemAdd(query(in: place, adding: more) as CFDictionary, nil)
        guard status == errSecSuccess else { throw Self.fault(status) }
    }

    /// The query of the item. An item of the data-protection Keychain is found whether it syncs or not.
    private func query(in place: Keychain, adding more: [CFString: Any] = [:]) -> [CFString: Any] {
        var query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: Self.service, kSecAttrAccount: Self.account]
        if place == .synced {
            query[kSecUseDataProtectionKeychain] = true
            query[kSecAttrSynchronizable] = kSecAttrSynchronizableAny
        }
        return query.merging(more) { _, new in new }
    }

    private static func fault(_ status: OSStatus) -> SpotError {
        .fault("Openspot cannot reach your account key in the Keychain. \(SecCopyErrorMessageString(status, nil) as String? ?? "Error \(status).")")
    }
}
