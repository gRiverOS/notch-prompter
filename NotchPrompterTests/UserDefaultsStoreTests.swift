import XCTest
@testable import NotchPrompter

final class UserDefaultsStoreTests: XCTestCase {
    var defaults: UserDefaults!
    var store: UserDefaultsStore!

    override func setUp() {
        let suite = "cl.gustavo.NotchPrompter.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        store = UserDefaultsStore(defaults: defaults)
    }

    func testDefaultsWhenEmpty() {
        XCTAssertEqual(store.text, "")
        XCTAssertEqual(store.speed, PrompterEngine.defaultSpeed)
    }

    func testRoundTripsTextAndSpeed() {
        store.text = "guion"
        store.speed = 120
        let reloaded = UserDefaultsStore(defaults: defaults)
        XCTAssertEqual(reloaded.text, "guion")
        XCTAssertEqual(reloaded.speed, 120)
    }
}
