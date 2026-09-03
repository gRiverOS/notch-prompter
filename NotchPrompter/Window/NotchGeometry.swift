import CoreGraphics

/// Cálculo puro del frame del panel a partir de la geometría de la pantalla.
/// Coordenadas AppKit: origen abajo a la izquierda, Y crece hacia arriba.
enum NotchGeometry {
    static let panelSize = CGSize(width: 560, height: 130)

    /// - Parameters:
    ///   - screenFrame: `NSScreen.frame`.
    ///   - topLeftArea: `NSScreen.auxiliaryTopLeftArea` (nil si no hay notch).
    ///   - topRightArea: `NSScreen.auxiliaryTopRightArea` (nil si no hay notch).
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
