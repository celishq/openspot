import CommonCrypto
import Foundation

enum Scrypt {
    static func key(password: Data, salt: Data, cost: Int, blockSize: Int, parallel: Int, length: Int) -> Data? {
        guard cost > 1, cost & (cost - 1) == 0, blockSize > 0, parallel > 0 else { return nil }
        let chunk = 128 * blockSize
        guard var blocks = pbkdf2(password, salt: salt, length: chunk * parallel) else { return nil }
        var words = [UInt32](repeating: 0, count: chunk / 4)
        for index in 0..<parallel {
            let start = index * chunk
            blocks.withUnsafeBytes { bytes in
                for word in words.indices {
                    words[word] = bytes.loadUnaligned(fromByteOffset: start + word * 4, as: UInt32.self).littleEndian
                }
            }
            mix(&words, cost: cost, blockSize: blockSize)
            blocks.withUnsafeMutableBytes { bytes in
                for word in words.indices {
                    bytes.storeBytes(of: words[word].littleEndian, toByteOffset: start + word * 4, as: UInt32.self)
                }
            }
        }
        return pbkdf2(password, salt: blocks, length: length)
    }

    static func pbkdf2(_ password: Data, salt: Data, length: Int) -> Data? {
        var output = Data(count: length)
        let status = output.withUnsafeMutableBytes { out in
            password.withUnsafeBytes { word in
                salt.withUnsafeBytes { salt in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        word.baseAddress?.assumingMemoryBound(to: CChar.self), password.count,
                        salt.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 1,
                        out.baseAddress?.assumingMemoryBound(to: UInt8.self), length
                    )
                }
            }
        }
        return status == kCCSuccess ? output : nil
    }

    private static func mix(_ block: inout [UInt32], cost: Int, blockSize: Int) {
        let size = block.count
        var table = [UInt32](repeating: 0, count: size * cost)
        var scratch = [UInt32](repeating: 0, count: size)
        block.withUnsafeMutableBufferPointer { block in
            table.withUnsafeMutableBufferPointer { table in
                scratch.withUnsafeMutableBufferPointer { scratch in
                    var from = block.baseAddress!
                    var into = scratch.baseAddress!
                    for index in 0..<cost {
                        (table.baseAddress! + index * size).update(from: from, count: size)
                        blockMix(from, into: into, blockSize: blockSize)
                        swap(&from, &into)
                    }
                    for _ in 0..<cost {
                        let row = Int(from[(2 * blockSize - 1) * 16] & UInt32(cost - 1))
                        let line = table.baseAddress! + row * size
                        for word in 0..<size { from[word] ^= line[word] }
                        blockMix(from, into: into, blockSize: blockSize)
                        swap(&from, &into)
                    }
                    if from != block.baseAddress! { block.baseAddress!.update(from: from, count: size) }
                }
            }
        }
    }

    private static func blockMix(_ block: UnsafeMutablePointer<UInt32>, into out: UnsafeMutablePointer<UInt32>, blockSize: Int) {
        var state = (block + (2 * blockSize - 1) * 16).withMemoryRebound(to: UInt32.self, capacity: 16) { pointer in
            (0..<16).map { pointer[$0] }
        }
        state.withUnsafeMutableBufferPointer { state in
            let x = state.baseAddress!
            for index in 0..<(2 * blockSize) {
                for word in 0..<16 { x[word] ^= block[index * 16 + word] }
                salsa(x)
                (out + (index % 2 == 0 ? index / 2 : blockSize + index / 2) * 16).update(from: x, count: 16)
            }
        }
    }

    private static func salsa(_ b: UnsafeMutablePointer<UInt32>) {
        var x0 = b[0], x1 = b[1], x2 = b[2], x3 = b[3], x4 = b[4], x5 = b[5], x6 = b[6], x7 = b[7]
        var x8 = b[8], x9 = b[9], x10 = b[10], x11 = b[11], x12 = b[12], x13 = b[13], x14 = b[14], x15 = b[15]
        for _ in 0..<4 {
            x4 ^= (x0 &+ x12).rotated(7); x8 ^= (x4 &+ x0).rotated(9); x12 ^= (x8 &+ x4).rotated(13); x0 ^= (x12 &+ x8).rotated(18)
            x9 ^= (x5 &+ x1).rotated(7); x13 ^= (x9 &+ x5).rotated(9); x1 ^= (x13 &+ x9).rotated(13); x5 ^= (x1 &+ x13).rotated(18)
            x14 ^= (x10 &+ x6).rotated(7); x2 ^= (x14 &+ x10).rotated(9); x6 ^= (x2 &+ x14).rotated(13); x10 ^= (x6 &+ x2).rotated(18)
            x3 ^= (x15 &+ x11).rotated(7); x7 ^= (x3 &+ x15).rotated(9); x11 ^= (x7 &+ x3).rotated(13); x15 ^= (x11 &+ x7).rotated(18)
            x1 ^= (x0 &+ x3).rotated(7); x2 ^= (x1 &+ x0).rotated(9); x3 ^= (x2 &+ x1).rotated(13); x0 ^= (x3 &+ x2).rotated(18)
            x6 ^= (x5 &+ x4).rotated(7); x7 ^= (x6 &+ x5).rotated(9); x4 ^= (x7 &+ x6).rotated(13); x5 ^= (x4 &+ x7).rotated(18)
            x11 ^= (x10 &+ x9).rotated(7); x8 ^= (x11 &+ x10).rotated(9); x9 ^= (x8 &+ x11).rotated(13); x10 ^= (x9 &+ x8).rotated(18)
            x12 ^= (x15 &+ x14).rotated(7); x13 ^= (x12 &+ x15).rotated(9); x14 ^= (x13 &+ x12).rotated(13); x15 ^= (x14 &+ x13).rotated(18)
        }
        b[0] &+= x0; b[1] &+= x1; b[2] &+= x2; b[3] &+= x3; b[4] &+= x4; b[5] &+= x5; b[6] &+= x6; b[7] &+= x7
        b[8] &+= x8; b[9] &+= x9; b[10] &+= x10; b[11] &+= x11; b[12] &+= x12; b[13] &+= x13; b[14] &+= x14; b[15] &+= x15
    }
}

private extension UInt32 {
    func rotated(_ count: UInt32) -> UInt32 {
        (self << count) | (self >> (32 - count))
    }
}
