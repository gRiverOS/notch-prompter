import AppKit
import XCTest
@testable import NotchPrompter

/// Guards the app icon: every size declared in the asset catalog must exist at
/// exactly the pixel dimensions it claims, and the built app must reference it.
final class AppIconTests: XCTestCase {
    private struct Entry: Decodable {
        let size: String
        let scale: String
        let filename: String
    }

    private struct Manifest: Decodable {
        let images: [Entry]
    }

    private var iconSet: URL!
    private var manifest: Manifest!

    override func setUpWithError() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        iconSet = root.appending(path: "NotchPrompter/Resources/Assets.xcassets/AppIcon.appiconset")
        let data = try Data(contentsOf: iconSet.appending(path: "Contents.json"))
        manifest = try JSONDecoder().decode(Manifest.self, from: data)
    }

    func testCatalogDeclaresEverySizeMacOSExpects() {
        let declared = Set(manifest.images.map { "\($0.size)@\($0.scale)" })
        let expected: Set<String> = [
            "16x16@1x", "16x16@2x",
            "32x32@1x", "32x32@2x",
            "128x128@1x", "128x128@2x",
            "256x256@1x", "256x256@2x",
            "512x512@1x", "512x512@2x",
        ]
        XCTAssertEqual(declared, expected)
    }

    func testEveryDeclaredImageExistsAtItsClaimedPixelSize() throws {
        for image in manifest.images {
            let url = iconSet.appending(path: image.filename)
            let data = try XCTUnwrap(try? Data(contentsOf: url), "missing \(image.filename)")
            let rep = try XCTUnwrap(NSBitmapImageRep(data: data), "\(image.filename) is not a PNG")

            let points = try XCTUnwrap(Int(image.size.split(separator: "x").first ?? ""))
            let factor = image.scale == "2x" ? 2 : 1
            let expected = points * factor

            XCTAssertEqual(rep.pixelsWide, expected, "\(image.filename) width")
            XCTAssertEqual(rep.pixelsHigh, expected, "\(image.filename) height")
        }
    }

    /// The SVG is a design source, not a runtime resource: it lives outside the
    /// target's source tree so Xcode does not copy it into the app bundle.
    func testTheSourceSVGIsVersionedOutsideTheAppBundle() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: root.appending(path: "Design/AppIcon.svg").path),
            "Design/AppIcon.svg must stay in the repo so scripts/make-icon.sh can regenerate the set"
        )
        let bundle = Bundle(for: PrompterEngine.self)
        XCTAssertNil(bundle.url(forResource: "AppIcon", withExtension: "svg"),
                     "the SVG must not ship inside the app bundle")
    }

    func testTheBuiltAppReferencesTheIcon() {
        let bundle = Bundle(for: PrompterEngine.self)
        XCTAssertEqual(bundle.object(forInfoDictionaryKey: "CFBundleIconName") as? String, "AppIcon")
    }
}
