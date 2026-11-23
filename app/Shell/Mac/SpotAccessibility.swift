import ApplicationServices
import Foundation

enum SpotAccessibility {
    static let settings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    static func ask() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
}
