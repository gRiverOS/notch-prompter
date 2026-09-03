import CoreGraphics

/// Pure computation of the panel frame from the screen geometry.
/// AppKit coordinates: origin at the bottom-left, Y grows upwards.
enum NotchGeometry {
    static let panelSize = CGSize(width: 560, height: 130)

    /// - Parameters:
    ///   - screenFrame: `NSScreen.frame`.
    ///   - topLeftArea: `NSScreen.auxiliaryTopLeftArea` (nil when there is no notch).
    ///   - topRightArea: `NSScreen.auxiliaryTopRightArea` (nil when there is no notch).
    static func panelFrame(
        screenFrame: CGRect,
        topLeftArea: CGRect?,
        topRightArea: CGRect?,
        size: CGSize = panelSize
    ) -> CGRect {
        let centerX: CGFloat
        if let left = topLeftArea, let right = topRightArea, right.minX > left.maxX {
            centerX = (left.maxX + right.minX) / 2
        } else {
            centerX = screenFrame.midX
        }
        let origin = CGPoint(
            x: centerX - size.width / 2,
            y: screenFrame.maxY - size.height
        )
        return CGRect(origin: origin, size: size)
    }
}
