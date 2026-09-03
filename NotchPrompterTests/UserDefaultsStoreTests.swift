import XCTest
@testable import NotchPrompter

final class UserDefaultsStoreTests: XCTestCase {
    var suite: String!
    var defaults: UserDefaults!
    var store: UserDefaultsStore!

    override func setUp() {
        suite = "cl.gustavo.NotchPrompter.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        store = UserDefaultsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
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
