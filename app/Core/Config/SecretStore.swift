import Foundation
import Security
import Synchronization

public final class SecretStore: Equatable, Sendable {
    public typealias Values = [String: [String: String]]

    static let shortest = 8
    private static let service = "dev.openspot.secrets"
    private static let account = "values"
    private static let fileName = "secrets.json"
    let file: URL?
    private let kept = Mutex<Values?>(nil)

    init(file: URL?) {
        self.file = file
    }

    public static func == (left: SecretStore, right: SecretStore) -> Bool {
        left === right
    }

    public static func standard(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        devState: String? = Bundle.main.object(forInfoDictionaryKey: "OpenspotDevState") as? String
    ) -> SecretStore {
        standard(own: SpotsFolder.ownConfig(environment: environment, devState: devState))
    }

    static func standard(own: URL?) -> SecretStore {
        SecretStore(file: own?.appendingPathComponent(fileName))
    }

    @discardableResult
    public func read() throws -> Values {
        try kept.withLock { values in
            if let values { return values }
            let read = try load()
            values = read
            return read
        }
    }

    func values(of spot: String) -> [String: String] {
        kept.withLock { $0?[spot] ?? [:] }
    }

    func keep(_ value: String?, key: String, of spot: String) throws {
        _ = try change { $0[spot, default: [:]][key] = value }
    }

    func remove(where isGone: (String) -> Bool) throws -> Values {
        try change { all in
            let gone = all.filter { isGone($0.key) }
            for spot in gone.keys { all[spot] = nil }
            return gone
        }
    }

    private func change<Result: Sendable>(_ work: (inout Values) -> Result) throws -> Result {
        try kept.withLock { values in
            var all = try values ?? load()
            let result = work(&all)
            all = all.filter { !$0.value.isEmpty }
            try write(all)
            values = all
            return result
        }
    }

    private func load() throws -> Values {
        let data: Data?
        if let file {
            data = FileManager.default.fileExists(atPath: file.path) ? try Data(contentsOf: file) : nil
        } else {
            data = try item()
        }
        guard let data else { return [:] }
        return try JSONDecoder().decode(Values.self, from: data)
    }

    private func write(_ all: Values) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(all)
        if let file {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions: 0o600])
            return try data.write(to: file)
        }
        guard !all.isEmpty else {
            let status = SecItemDelete(query() as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw Self.fault(status) }
            return
        }
        let status = SecItemUpdate(query() as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            let added = SecItemAdd(query(adding: [kSecValueData: data, kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock]) as CFDictionary, nil)
            guard added == errSecSuccess else { throw Self.fault(added) }
            return
        }
        guard status == errSecSuccess else { throw Self.fault(status) }
    }

    private func item() throws -> Data? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query(adding: [kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]) as CFDictionary, &result)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw Self.fault(status) }
        return data
    }

    private func query(adding more: [CFString: Any] = [:]) -> [CFString: Any] {
        var query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: Self.service, kSecAttrAccount: Self.account]
        if AccountStore.keychain == .synced { query[kSecUseDataProtectionKeychain] = true }
        return query.merging(more) { _, new in new }
    }

    private static func fault(_ status: OSStatus) -> SpotError {
        .fault("Openspot cannot reach the secrets of your spots in the Keychain. \(SecCopyErrorMessageString(status, nil) as String? ?? "Error \(status).")")
    }
}
