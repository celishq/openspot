import Foundation

public struct PreviousApp<App: Equatable> {
    public private(set) var app: App?

    public init() {}

    public mutating func show(over front: App?, own: App) {
        if front != own { app = front }
    }
}
