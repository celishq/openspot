import CryptoKit
import Foundation

extension AccountKey {
    public func choices(at place: Int) -> [String] {
        guard let words, words.indices.contains(place - 1) else { return [] }
        let seed = "\(publicKey):\(place)"
        let digest = { (text: String) in Array(SHA256.hash(data: Data(text.utf8))) }
        var picked = [words[place - 1]]
        var round = 0
        while picked.count < 4 {
            let bytes = digest("\(seed):\(round)")
            let word = AccountWords.all[(Int(bytes[0]) << 8 | Int(bytes[1])) % AccountWords.all.count]
            if !picked.contains(word) { picked.append(word) }
            round += 1
        }
        return picked.sorted { digest("\(seed):\($0)").lexicographicallyPrecedes(digest("\(seed):\($1)")) }
    }
}
