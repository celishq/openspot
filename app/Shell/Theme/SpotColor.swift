import AppKit
import SwiftUI

nonisolated struct SpotColor: ShapeStyle, View, Hashable {
    static let clear = SpotColor(dark: .clear, light: .clear)

    private let dark: Color.Resolved
    private let light: Color.Resolved
    private let system: Color?

    init(dark: NSColor, light: NSColor) {
        if let dark = Self.resolved(dark), let light = Self.resolved(light) {
            self.init(dark: dark, light: light, system: nil)
        } else {
            self.init(system: Color(nsColor: NSColor(name: nil) { SpotTheme.isDark($0) ? dark : light }))
        }
    }

    init(system: Color) {
        self.init(dark: Self.blank, light: Self.blank, system: system)
    }

    private init(dark: Color.Resolved, light: Color.Resolved, system: Color?) {
        self.dark = dark
        self.light = light
        self.system = system
    }

    func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        if let system { return system.resolve(in: environment) }
        return environment.colorScheme == .dark ? dark : light
    }

    var body: some View {
        Rectangle().fill(self)
    }

    func opacity(_ amount: Double) -> SpotColor {
        if let system { return SpotColor(system: system.opacity(amount)) }
        var dark = dark
        var light = light
        dark.opacity *= Float(amount)
        light.opacity *= Float(amount)
        return SpotColor(dark: dark, light: light, system: nil)
    }

    func color(in scheme: ColorScheme) -> Color {
        system ?? Color(scheme == .dark ? dark : light)
    }

    var color: Color {
        if let system { return system }
        let dark = NSColor(Color(dark))
        let light = NSColor(Color(light))
        return Color(nsColor: NSColor(name: nil) { SpotTheme.isDark($0) ? dark : light })
    }

    private static let blank = Color.Resolved(red: 0, green: 0, blue: 0, opacity: 0)

    private static func resolved(_ color: NSColor) -> Color.Resolved? {
        guard color.type == .componentBased, let color = color.usingColorSpace(.sRGB) else { return nil }
        return Color.Resolved(colorSpace: .sRGB, red: Float(color.redComponent), green: Float(color.greenComponent), blue: Float(color.blueComponent), opacity: Float(color.alphaComponent))
    }
}
