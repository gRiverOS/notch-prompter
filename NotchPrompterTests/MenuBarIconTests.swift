import AppKit
import XCTest
@testable import NotchPrompter

/// Guards the menu bar icon. The failure this catches is the classic one: an
/// image that is not marked as a template renders as a solid black blob on the
/// dark menu bar instead of adapting to it.
final class MenuBarIconTests: XCTestCase {
    static let assetName = "MenuBarIcon"

    private var imageSet: URL!

    override func setUpWithError() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        imageSet = root.appending(
            path: "NotchPrompter/Resources/Assets.xcassets/\(Self.assetName).imageset"
        )
    }

    func testTheImageSetIsMarkedAsATemplate() throws {
        let data = try Data(contentsOf: imageSet.appending(path: "Contents.json"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let properties = try XCTUnwrap(json["properties"] as? [String: Any])
        XCTAssertEqual(properties["template-rendering-intent"] as? String, "template")
    }

    func testBothScalesExistAtEighteenPoints() throws {
        for (file, pixels) in [("menubar_18.png", 18), ("menubar_36.png", 36)] {
            let data = try XCTUnwrap(try? Data(contentsOf: imageSet.appending(path: file)),
                                     "missing \(file)")
            let rep = try XCTUnwrap(NSBitmapImageRep(data: data), "\(file) is not a PNG")
            XCTAssertEqual(rep.pixelsWide, pixels, "\(file) width")
            XCTAssertEqual(rep.pixelsHigh, pixels, "\(file) height")
        }
    }

    /// End-to-end: the asset compiles into the app bundle and loads as a template.
    func testTheIconLoadsFromTheAppBundleAsATemplate() throws {
        let bundle = Bundle(for: PrompterEngine.self)
        let image = try XCTUnwrap(bundle.image(forResource: Self.assetName),
                                  "\(Self.assetName) is missing from the built app")
        XCTAssertTrue(image.isTemplate, "\(Self.assetName) must be a template image")
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
    }
}
