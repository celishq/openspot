import CoreGraphics

extension Toast {
    public static func size(fitting fits: (CGFloat) -> CGSize) -> CGSize {
        let widest = SpotTokens.toastWidest
        let width = min(fits(widest).width.rounded(.up) + 1, widest)
        return CGSize(width: width, height: fits(width).height.rounded(.up))
    }
}
