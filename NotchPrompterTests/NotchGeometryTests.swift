import XCTest
@testable import NotchPrompter

final class NotchGeometryTests: XCTestCase {
    // MacBook Pro 14": pantalla 1512x982, notch de 38 pt entre las áreas auxiliares.
    let mbp14 = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let leftArea = CGRect(x: 0, y: 944, width: 700, height: 38)
    let rightArea = CGRect(x: 820, y: 944, width: 692, height: 38)

    func testPanelIsCenteredOnNotchAndHangsBelowMenuBar() {
        let frame = NotchGeometry.panelFrame(screenFrame: mbp14, topLeftArea: leftArea, topRightArea: rightArea, menuBarHeight: 38)
        // Centro del notch = (700 + 820) / 2 = 760
        XCTAssertEqual(frame.midX, 760, accuracy: 0.001)
        // Cuelga desde el borde inferior de la barra de menú, sin taparla.
        XCTAssertEqual(frame.maxY, 982 - 38, accuracy: 0.001)
        XCTAssertEqual(frame.size, NotchGeometry.panelSize)
    }

    func testWithoutNotchPanelIsCenteredOnScreen() {
        let external = CGRect(x: 1512, y: 200, width: 2560, height: 1440)
        let frame = NotchGeometry.panelFrame(screenFrame: external, topLeftArea: nil, topRightArea: nil, menuBarHeight: 24)
        XCTAssertEqual(frame.midX, external.midX, accuracy: 0.001)
        XCTAssertEqual(frame.maxY, external.maxY - 24, accuracy: 0.001)
    }

    func testAreasThatDoNotLeaveGapCountAsNoNotch() {
        let left = CGRect(x: 0, y: 944, width: 756, height: 38)
        let right = CGRect(x: 756, y: 944, width: 756, height: 38)
        let frame = NotchGeometry.panelFrame(screenFrame: mbp14, topLeftArea: left, topRightArea: right, menuBarHeight: 38)
        XCTAssertEqual(frame.midX, mbp14.midX, accuracy: 0.001)
    }

    func testPanelSizeMatchesSpec() {
        XCTAssertEqual(NotchGeometry.panelSize, CGSize(width: 560, height: 130))
    }
}
