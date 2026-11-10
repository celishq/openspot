import Foundation

/// One piece of a typed sum: a number, an operator or a bracket, or a word such as `sqrt`, `pi` or `of`.
enum CalcToken: Equatable, Sendable {
    case number(Double)
    /// An operator or a bracket, written as one of `+ - * / ^ % ( )`.
    case symbol(Character)
    /// Letters, in lower case.
    case word(String)

    private static let symbols: [Character: Character] = [
        "+": "+", "-": "-", "−": "-", "*": "*", "×": "*", "·": "*", "/": "/", "÷": "/", "^": "^", "%": "%", "(": "(", ")": ")",
    ]

    /// The pieces of the text, or nil when it holds a character that no sum uses. A decimal point is always a dot, and also
    /// a comma where the Mac writes one. Where the Mac writes a dot, a comma before three digits groups thousands.
    static func tokens(in text: String, locale: Locale) -> [CalcToken]? {
        let decimalComma = locale.decimalSeparator == ","
        let characters = Array(text)
        var tokens: [CalcToken] = []
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character.isWhitespace {
                index += 1
            } else if character.isASCII, character.isNumber || (Self.isPoint(character, decimalComma) && Self.isDigit(characters, index + 1)) {
                guard let number = Self.number(in: characters, from: &index, decimalComma: decimalComma) else { return nil }
                tokens.append(.number(number))
            } else if let symbol = symbols[character] {
                tokens.append(.symbol(symbol))
                index += 1
            } else if character.isLetter {
                var word = ""
                while index < characters.count, characters[index].isLetter {
                    word.append(characters[index])
                    index += 1
                }
                tokens.append(.word(word.lowercased()))
            } else {
                return nil
            }
        }
        return tokens
    }

    private static func isPoint(_ character: Character, _ decimalComma: Bool) -> Bool {
        character == "." || (decimalComma && character == ",")
    }

    private static func isDigit(_ characters: [Character], _ index: Int) -> Bool {
        index < characters.count && characters[index].isASCII && characters[index].isNumber
    }

    /// Reads a number with its digits, its decimal point and an exponent such as `e3`. Returns nil for a point with no
    /// digits after it, or a comma that neither groups nor marks a decimal.
    private static func number(in characters: [Character], from index: inout Int, decimalComma: Bool) -> Double? {
        var text = ""
        var hasPoint = false
        while index < characters.count {
            let character = characters[index]
            if isDigit(characters, index) {
                text.append(character)
            } else if isPoint(character, decimalComma), !hasPoint, isDigit(characters, index + 1) {
                text.append(".")
                hasPoint = true
            } else if character == ",", !decimalComma, !hasPoint, (1...3).allSatisfy({ isDigit(characters, index + $0) }), !isDigit(characters, index + 4) {
                index += 1
                continue
            } else if character == "," && !decimalComma {
                return nil
            } else {
                break
            }
            index += 1
        }
        if index < characters.count, characters[index] == "e" || characters[index] == "E" {
            var end = index + 1
            if end < characters.count, characters[end] == "+" || characters[end] == "-" { end += 1 }
            if isDigit(characters, end) {
                text += String(characters[index..<end])
                index = end
                while isDigit(characters, index) {
                    text.append(characters[index])
                    index += 1
                }
            }
        }
        return Double(text)
    }
}
