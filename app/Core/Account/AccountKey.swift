import CommonCrypto
import CryptoKit
import Foundation
import P256K

public struct AccountKey: Equatable, Sendable {
    private static let salt = Data("celis-identity-v1".utf8)
    private static let info = Data("account-secp256k1".utf8)

    public let words: [String]?
    private let secret: Data

    public static func make() throws -> AccountKey {
        var entropy = Data(count: 16)
        let status = entropy.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard status == errSecSuccess else { throw SpotError.fault("Openspot cannot make a key, because the Mac gave no random bytes.") }
        return try AccountKey(words: Self.words(of: entropy))
    }

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

    public var publicKey: String {
        Data((try? P256K.Schnorr.PrivateKey(dataRepresentation: secret))?.xonly.bytes ?? []).hex
    }

    public var npub: String {
        Bech32.encode("npub", Data(hex: publicKey) ?? Data())
    }

    public var nsec: String {
        Bech32.encode("nsec", secret)
    }

    public func sign(_ digest: Data) throws -> Data {
        var message = Array(digest)
        var random = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &random)
        return try P256K.Schnorr.PrivateKey(dataRepresentation: secret).signature(message: &message, auxiliaryRand: &random, strict: true).dataRepresentation
    }

    public static func isValid(_ signature: Data, of digest: Data, by publicKey: String) -> Bool {
        guard let key = Data(hex: publicKey), key.count == 32, signature.count == 64,
              let parsed = try? P256K.Schnorr.SchnorrSignature(dataRepresentation: signature) else { return false }
        var message = Array(digest)
        return P256K.Schnorr.XonlyKey(dataRepresentation: key).isValid(parsed, for: &message)
    }

    static func words(of entropy: Data) -> [String] {
        let check = checksum(of: entropy)
        var bits: [Bool] = []
        for byte in entropy {
            for bit in 0..<8 { bits.append(byte >> (7 - bit) & 1 == 1) }
        }
        for bit in 0..<4 { bits.append(check >> (3 - bit) & 1 == 1) }
        return stride(from: 0, to: 132, by: 11).map { AccountWords.all[Int(number(bits[$0..<$0 + 11]))] }
    }

    private static func checksum(of entropy: Data) -> UInt16 {
        UInt16(Array(CryptoKit.SHA256.hash(data: entropy))[0] >> 4)
    }

    private static func number(_ bits: ArraySlice<Bool>) -> UInt16 {
        bits.reduce(UInt16(0)) { $0 << 1 | ($1 ? 1 : 0) }
    }

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
