import CommonCrypto
import CryptoKit
import Foundation

enum RaycastCipher {
    enum Fault: Error, Equatable, Sendable {
        case notExport
        case passphrase
        case version(String)

        var reason: String {
            switch self {
            case .notExport: "This isn't a Raycast export. Choose the .rayconfig file that Raycast saved."
            case .passphrase: "Wrong passphrase. Raycast shows it in Settings → Advanced → Export."
            case .version(let version): "Openspot can't read this export (schema \(version)). Export again from Raycast 2 or newer, then choose the new file."
            }
        }
    }

    static let magic = Data("RAYCFG3\n".utf8)
    static let schema = 3
    static let cost = 16384
    static let blockSize = 8
    static let tagSize = 16

    static func open(_ data: Data, passphrase: String) throws(Fault) -> Data {
        if data.starts(with: magic) { return try openSecond(data, passphrase: passphrase) }
        return try openFirst(data, passphrase: passphrase)
    }

    static func header(of data: Data) throws(Fault) -> (iv: Data, salt: Data, body: Range<Int>) {
        let start = magic.count + 4
        guard data.count > start + tagSize else { throw .notExport }
        let length = data.subdata(in: magic.count..<start).withUnsafeBytes { Int($0.loadUnaligned(as: UInt32.self).littleEndian) }
        guard length > 0, start + length + tagSize <= data.count,
              let json = Gzip.unzip(data.subdata(in: start..<start + length)),
              let header = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else { throw .notExport }
        let version = header["schemaVersion"].map { "\($0)" } ?? "?"
        guard version == String(schema) else { throw .version(version) }
        guard let keys = header["encryption"] as? [String: Any], let iv = (keys["iv"] as? String).flatMap(Self.bytes),
              let salt = (keys["salt"] as? String).flatMap(Self.bytes) else { throw .notExport }
        return (iv, salt, start + length..<data.count)
    }

    private static func openSecond(_ data: Data, passphrase: String) throws(Fault) -> Data {
        let header = try header(of: data)
        let body = data.subdata(in: header.body)
        guard let key = Scrypt.key(password: Data(passphrase.utf8), salt: header.salt, cost: cost, blockSize: blockSize, parallel: 1, length: 32),
              let nonce = try? AES.GCM.Nonce(data: header.iv),
              let box = try? AES.GCM.SealedBox(nonce: nonce, ciphertext: body.dropLast(tagSize), tag: body.suffix(tagSize)) else { throw .notExport }
        guard let zipped = try? AES.GCM.open(box, using: SymmetricKey(data: key)) else { throw .passphrase }
        guard let json = Gzip.unzip(zipped) else { throw .notExport }
        return json
    }

    private static func openFirst(_ data: Data, passphrase: String) throws(Fault) -> Data {
        guard data.count >= 32, data.count % 16 == 0 else { throw .notExport }
        let key = Data(SHA256.hash(data: Data(passphrase.utf8)))
        let iv = data.prefix(16)
        let body = data.dropFirst(16)
        var out = Data(count: body.count + 16)
        var written = 0
        let status = out.withUnsafeMutableBytes { out in
            key.withUnsafeBytes { key in
                iv.withUnsafeBytes { iv in
                    body.withUnsafeBytes { body in
                        CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                                key.baseAddress, key.count, iv.baseAddress, body.baseAddress, body.count,
                                out.baseAddress, out.count, &written)
                    }
                }
            }
        }
        guard status == kCCSuccess, Gzip.isGzip(out.prefix(written)) else { throw .passphrase }
        guard let json = Gzip.unzip(out.prefix(written)) else { throw .notExport }
        return json
    }

    static func bytes(_ hex: String) -> Data? {
        guard hex.count % 2 == 0 else { return nil }
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }
}
