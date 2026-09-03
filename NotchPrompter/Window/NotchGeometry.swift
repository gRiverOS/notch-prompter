import CoreGraphics

/// Cálculo puro del frame del panel a partir de la geometría de la pantalla.
/// Coordenadas AppKit: origen abajo a la izquierda, Y crece hacia arriba.
enum NotchGeometry {
    static let panelSize = CGSize(width: 560, height: 130)

    /// - Parameters:
    ///   - screenFrame: `NSScreen.frame`.
    ///   - topLeftArea: `NSScreen.auxiliaryTopLeftArea` (nil si no hay notch).
    ///   - topRightArea: `NSScreen.auxiliaryTopRightArea` (nil si no hay notch).
    ///   - menuBarHeight: alto de la barra de menú (`frame.maxY - visibleFrame.maxY`).
    ///     El panel cuelga desde su borde inferior para no tapar los ítems de la barra.
    static func panelFrame(
        screenFrame: CGRect,
        topLeftArea: CGRect?,
        topRightArea: CGRect?,
        menuBarHeight: CGFloat,
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
            y: screenFrame.maxY - menuBarHeight - size.height
        )
        return CGRect(origin: origin, size: size)
    }
}
