import CommonCrypto
import CryptoKit
import Foundation
import P256K

/// The person's account key: a secp256k1 key that signs each release of their spots. It comes from 12 BIP-39 words, the
/// same way celis makes it, so the same words give the same key in both apps. A key given as an `nsec` has no words.
public struct AccountKey: Equatable, Sendable {
    private static let salt = Data("celis-identity-v1".utf8)
    private static let info = Data("account-secp256k1".utf8)

    /// The 12 words that make the key again, or nil for a key given as an `nsec`.
    public let words: [String]?
    private let secret: Data

    /// A new key from 12 new words.
    public static func make() throws -> AccountKey {
        var entropy = Data(count: 16)
        let status = entropy.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard status == errSecSuccess else { throw SpotError.fault("Openspot cannot make a key, because the Mac gave no random bytes.") }
        return try AccountKey(words: Self.words(of: entropy))
    }

    /// The key of 12 BIP-39 words. Throws a fault for a word that is not in the list, a count other than 12, or a
    /// checksum that does not match.
    public init(words: [String]) throws {
        let words = words.map { $0.lowercased() }
        guard words.count == 12 else { throw SpotError.fault("An account key has 12 words, and this has \(words.count).") }
        var bits: [Bool] = []
        for word in words {
            guard let index = AccountWords.all.firstIndex(of: word) else { throw SpotError.fault("\(word) is not a word of an account key.") }
            for bit in 0..<11 { bits.append(index >> (10 - bit) & 1 == 1) }
        }
        let entropy = Data(stride(from: 0, to: 128, by: 8).map { UInt8(Self.number(bits[$0..<$0 + 8])) })
        guard Self.number(bits[128...]) == Self.checksum(of: entropy) else {
            throw SpotError.fault("These words are not an account key: one of them is wrong.")
        }
        let seed = try Self.seed(of: words.joined(separator: " "))
        let key = HKDF<CryptoKit.SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: seed), salt: Self.salt, info: Self.info, outputByteCount: 32)
        try self.init(words: words, secret: key.withUnsafeBytes { Data($0) })
    }

    /// The key that an `nsec` names (NIP-19).
    public init(nsec: String) throws {
        guard let secret = Bech32.decode(nsec.trimmingCharacters(in: .whitespacesAndNewlines), prefix: "nsec"), secret.count == 32 else {
            throw SpotError.fault("This is not an nsec.")
        }
        try self.init(words: nil, secret: secret)
    }

    private init(words: [String]?, secret: Data) throws {
        _ = try P256K.Schnorr.PrivateKey(dataRepresentation: secret)
        self.words = words
        self.secret = secret
    }

    /// The x-only public key in lowercase hex, as nostr events name their author.
    public var publicKey: String {
        Self.hex(Data((try? P256K.Schnorr.PrivateKey(dataRepresentation: secret))?.xonly.bytes ?? []))
    }

    public var npub: String {
        Bech32.encode("npub", Self.bytes(ofHex: publicKey) ?? Data())
    }

    public var nsec: String {
        Bech32.encode("nsec", secret)
    }

    /// The BIP-340 signature of 32 bytes, such as the id of an event.
    public func sign(_ digest: Data) throws -> Data {
        var message = Array(digest)
        var random = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &random)
        return try P256K.Schnorr.PrivateKey(dataRepresentation: secret).signature(message: &message, auxiliaryRand: &random, strict: true).dataRepresentation
    }

    /// Whether a BIP-340 signature of these bytes comes from the key of this hex.
    public static func isValid(_ signature: Data, of digest: Data, by publicKey: String) -> Bool {
        guard let key = bytes(ofHex: publicKey), key.count == 32, signature.count == 64,
              let parsed = try? P256K.Schnorr.SchnorrSignature(dataRepresentation: signature) else { return false }
        var message = Array(digest)
        return P256K.Schnorr.XonlyKey(dataRepresentation: key).isValid(parsed, for: &message)
    }

    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    static func bytes(ofHex text: String) -> Data? {
        guard text.count % 2 == 0 else { return nil }
        var data = Data()
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(index, offsetBy: 2)
            guard let byte = UInt8(text[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }

    /// The 12 words of 16 bytes of entropy, with the checksum of BIP-39 in the last word.
    static func words(of entropy: Data) -> [String] {
        let check = checksum(of: entropy)
        var bits: [Bool] = []
        for byte in entropy {
            for bit in 0..<8 { bits.append(byte >> (7 - bit) & 1 == 1) }
        }
        for bit in 0..<4 { bits.append(check >> (3 - bit) & 1 == 1) }
        return stride(from: 0, to: 132, by: 11).map { AccountWords.all[Int(number(bits[$0..<$0 + 11]))] }
    }

    /// The first 4 bits of the SHA-256 of the entropy.
    private static func checksum(of entropy: Data) -> UInt16 {
        UInt16(Array(CryptoKit.SHA256.hash(data: entropy))[0] >> 4)
    }

    /// The number that bits give, the first the highest.
    private static func number(_ bits: ArraySlice<Bool>) -> UInt16 {
        bits.reduce(UInt16(0)) { $0 << 1 | ($1 ? 1 : 0) }
    }

    /// The BIP-39 seed of a phrase with no passphrase: PBKDF2 with HMAC-SHA512, 2048 rounds and the salt `mnemonic`.
    private static func seed(of phrase: String) throws -> Data {
        let password = Array(phrase.decomposedStringWithCompatibilityMapping.utf8).map { Int8(bitPattern: $0) }
        let salt = Array("mnemonic".utf8)
        var seed = [UInt8](repeating: 0, count: 64)
        let status = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), password, password.count, salt, salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512), 2048, &seed, seed.count)
        guard status == kCCSuccess else { throw SpotError.fault("Openspot cannot make the key of these words.") }
        return Data(seed)
    }

    public static func == (lhs: AccountKey, rhs: AccountKey) -> Bool {
        lhs.secret == rhs.secret
    }
}
