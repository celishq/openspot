import Foundation

/// A letter or digit that runs a command from the panel, at its place on a US keyboard.
public struct CommandKey: Equatable, Sendable {
    private static let codes: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
        "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23,
        "9": 25, "7": 26, "8": 28, "0": 29, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40,
        "n": 45, "m": 46
    ]

    public let name: String
    public let code: UInt32

    public init?(name: String) {
        let lower = name.lowercased()
        guard let code = Self.codes[lower] else { return nil }
        self.name = lower
        self.code = code
    }

    /// Finds the key at a place on the keyboard.
    public init?(code: UInt32) {
        guard let name = Self.codes.first(where: { $0.value == code })?.key else { return nil }
        self.name = name
        self.code = code
    }
}
