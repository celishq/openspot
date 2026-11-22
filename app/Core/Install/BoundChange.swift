import Foundation

enum BoundChange {
    static func lines(of spots: [Spot], in folder: URL) -> [String] {
        let installed = (try? SpotsFolder(url: folder).scan().scripts) ?? []
        var lines: [String] = []
        for spot in spots {
            guard let old = installed.first(where: { $0.id == spot.id }) else { continue }
            let callers = installed.compactMap { other in
                other.bindings.first { $0.spot == spot.id && other.id != spot.id }.map { (other.name, $0.name) }
            }
            guard !callers.isEmpty else { continue }
            var changes = old.typedActions.filter { action in !spot.typedActions.contains { $0.id == action.id } }.map { "It removes the action \($0.id)." }
            for action in spot.typedActions {
                guard let before = old.typedActions.first(where: { $0.id == action.id }) else { continue }
                for input in action.inputs where input.isRequired && input.defaultValue == nil {
                    let was = before.inputs.first { $0.name == input.name }
                    if was?.isRequired != true || was?.defaultValue != nil { changes.append("It adds the required input \(input.name) to \(action.id).") }
                }
            }
            guard !changes.isEmpty else { continue }
            lines.append("This version changes what " + callers.map { "\($0.0) calls through \($0.1)" }.joined(separator: ", and what ") + ".")
            lines += changes
        }
        return lines
    }
}
