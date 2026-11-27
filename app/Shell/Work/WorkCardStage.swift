import Observation
import OpenspotCore

@MainActor
@Observable
final class WorkCardStage {
    var card: Work?
    var isShown = false
}
