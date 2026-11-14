import AppKit
import OpenspotCore

extension ScreenPlace.Screen {
    static var all: [ScreenPlace.Screen] {
        NSScreen.screens.map { ScreenPlace.Screen(frame: $0.frame, area: $0.visibleFrame) }
    }
}
