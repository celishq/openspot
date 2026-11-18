import Foundation
import Security

public struct AccountStore: Sendable {
    private static let service = "dev.openspot.account"
    private static let account = "key"
    private static let fileName = "account"
    let file: URL?

    init(file: URL?) {
        self.file = file
    }

    public static func standard(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        devState: String? = Bundle.main.object(forInfoDictionaryKey: "OpenspotDevState") as? String
    ) -> AccountStore {
        standard(own: SpotsFolder.ownConfig(environment: environment, devState: devState))
    }

    static func standard(own: URL?) -> AccountStore {
        AccountStore(file: own?.appendingPathComponent(fileName))
    }

    public func record() throws -> AccountRecord? {
        try lines().flatMap(AccountRecord.init(lines:))
    }

    public func key() throws -> AccountKey? {
        try record()?.key
    }

    public func keyMadeOnce(handle: String? = nil, on date: Date = Date()) throws -> AccountKey {
        if let key = try key() { return key }
        let key = try AccountKey.make()
        try keep(AccountRecord(key: key, handle: handle, since: date.formatted(.iso8601.year().month().day().dateSeparator(.dash))))
        return key
    }

    public func keep(_ key: AccountKey, isBackedUp: Bool = false) throws {
        try keep(AccountRecord(key: key, isBackedUp: isBackedUp))
    }

    public func keep(_ record: AccountRecord) throws {
        try write(record.lines)
    }

    public func markBackedUp() throws {
        guard var record = try record() else { return }
        record.isBackedUp = true
        try keep(record)
    }

    public func remove() throws {
        if let file {
            guard FileManager.default.fileExists(atPath: file.path) else { return }
            return try FileManager.default.removeItem(at: file)
        }
        let status = SecItemDelete(query(in: Self.keychain) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Self.fault(status) }
    }

    public func canSync() -> Bool {
        file == nil && Self.keychain == .synced
    }

    public func isSyncing() throws -> Bool {
        guard canSync() else { return false }
        return try item()?.isSynced == true
    }

    public func setSyncing(_ isOn: Bool) throws {
        guard canSync() else { throw SpotError.fault("This copy of Openspot keeps your account on this Mac only.") }
        guard let item = try item(), item.isSynced != isOn else { return }
        try add(item.data, in: .synced, syncing: isOn)
        let status = SecItemDelete(query(in: .synced, adding: [kSecAttrSynchronizable: item.isSynced]) as CFDictionary)
        guard status == errSecSuccess else { throw Self.fault(status) }
    }

    enum Keychain {
        case synced, login
    }

    static let keychain = findKeychain()

    private static func findKeychain() -> Keychain {
        let probe: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword, kSecAttrService: service + ".probe", kSecUseDataProtectionKeychain: true,
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
        let place = Self.keychain
        let status = SecItemUpdate(query(in: place) as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound { return try add(data, in: place, syncing: place == .synced) }
        guard status == errSecSuccess else { throw Self.fault(status) }
    }

    private func item() throws -> (data: Data, isSynced: Bool)? {
        var result: CFTypeRef?
        let more: [CFString: Any] = [kSecReturnData: true, kSecReturnAttributes: true, kSecMatchLimit: kSecMatchLimitOne]
        let status = SecItemCopyMatching(query(in: Self.keychain, adding: more) as CFDictionary, &result)
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
