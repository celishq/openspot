import Foundation

public struct ListedTheme: Identifiable, Equatable, Sendable {
    public enum Group: String, CaseIterable, Identifiable, Sendable {
        case builtIn = "Built In", yours = "Yours"

        public var id: Self {
            self
        }
    }

    public let name: String
    public let isBuiltIn: Bool
    public let isUsed: Bool
    public let colours: Theme.Colours
    public let layout: Theme.Layout

    public var id: String {
        name
    }

    public var group: Group {
        isBuiltIn ? .builtIn : .yours
    }
}
