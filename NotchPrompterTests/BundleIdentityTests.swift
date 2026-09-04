import XCTest
@testable import NotchPrompter

/// Pins the app's public name and its bundle identifier.
///
/// These two move independently on purpose. The display name is what people
/// read and can be changed freely; the bundle identifier is the key
/// `UserDefaults` stores the script and speed under, so changing it silently
/// wipes every user's saved script. This test makes that mistake loud.
final class BundleIdentityTests: XCTestCase {
    static let displayName = "Notch Prompter"
    static let bundleIdentifier = "cl.gustavo.NotchPrompter"

    private var bundle: Bundle!

    override func setUp() {
        bundle = Bundle(for: PrompterEngine.self)
    }

    func testTheVisibleNameHasASpace() {
        XCTAssertEqual(bundle.object(forInfoDictionaryKey: "CFBundleName") as? String, Self.displayName)
        XCTAssertEqual(
            bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
            Self.displayName
        )
    }

    /// Finder shows the file name, not CFBundleDisplayName, so the product
    /// itself has to carry the spaced name.
    func testTheBundleOnDiskCarriesTheVisibleName() {
        XCTAssertEqual(bundle.bundleURL.lastPathComponent, "\(Self.displayName).app")
    }

    func testTheBundleIdentifierIsUnchanged() {
        XCTAssertEqual(bundle.bundleIdentifier, Self.bundleIdentifier)
    }
}
