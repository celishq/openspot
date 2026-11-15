import Foundation
import OpenspotCore

struct SpotWindows: MacWindows {
    func frame() async throws -> WindowFrame {
        try await SpotBlocking.run { try SpotWindow.front().place }
    }

    func move(_ move: WindowMove) async throws {
        try await SpotBlocking.run { try SpotWindow.front().move(move) }
    }
}
