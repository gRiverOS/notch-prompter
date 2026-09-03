import XCTest
@testable import NotchPrompter

final class FakeClock: FrameClock {
    var onTick: ((TimeInterval) -> Void)?
    var startCount = 0
    var stopCount = 0
    func start(onTick: @escaping (TimeInterval) -> Void) { self.onTick = onTick; startCount += 1 }
    func stop() { onTick = nil; stopCount += 1 }
}

final class InMemoryStore: SettingsStore {
    var text: String = ""
    var speed: Double = PrompterEngine.defaultSpeed
}

@MainActor
final class PrompterEngineTests: XCTestCase {
    var clock: FakeClock!
    var store: InMemoryStore!
    var engine: PrompterEngine!

    override func setUp() {
        clock = FakeClock()
        store = InMemoryStore()
        engine = PrompterEngine(clock: clock, store: store)
        engine.contentHeight = 1000
    }

    func testInitialState() {
        XCTAssertEqual(engine.offset, 0)
        XCTAssertEqual(engine.speed, 60)
        XCTAssertFalse(engine.isPlaying)
    }

    func testLoadsTextAndSpeedFromStore() {
        store.text = "hola"
        store.speed = 90
        let e = PrompterEngine(clock: clock, store: store)
        XCTAssertEqual(e.text, "hola")
        XCTAssertEqual(e.speed, 90)
    }

    func testTickAdvancesOffsetBySpeedTimesDt() {
        engine.togglePlay()
        engine.tick(dt: 0.5)
        XCTAssertEqual(engine.offset, 30, accuracy: 0.001)
    }

    func testTickDoesNothingWhenPaused() {
        engine.tick(dt: 1)
        XCTAssertEqual(engine.offset, 0)
    }

    func testStopsAtEndOfContent() {
        engine.togglePlay()
        engine.tick(dt: 100) // 60 * 100 = 6000 > 1000
        XCTAssertEqual(engine.offset, 1000)
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(clock.stopCount, 1)
    }

    func testTogglePlayStartsAndStopsClock() {
        engine.togglePlay()
        XCTAssertTrue(engine.isPlaying)
        XCTAssertEqual(clock.startCount, 1)
        engine.togglePlay()
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(clock.stopCount, 1)
    }

    func testClockTicksReachEngine() {
        engine.togglePlay()
        clock.onTick?(1)
        XCTAssertEqual(engine.offset, 60, accuracy: 0.001)
    }

    func testSpeedStepsAndClamps() {
        engine.increaseSpeed()
        XCTAssertEqual(engine.speed, 70)
        engine.decreaseSpeed()
        engine.decreaseSpeed()
        XCTAssertEqual(engine.speed, 50)
        for _ in 0..<30 { engine.increaseSpeed() }
        XCTAssertEqual(engine.speed, 200)
        for _ in 0..<30 { engine.decreaseSpeed() }
        XCTAssertEqual(engine.speed, 20)
    }

    func testSpeedPersistsToStore() {
        engine.increaseSpeed()
        XCTAssertEqual(store.speed, 70)
    }

    func testTextPersistsToStore() {
        engine.text = "nuevo guion"
        XCTAssertEqual(store.text, "nuevo guion")
    }

    func testResetReturnsToZeroAndPauses() {
        engine.togglePlay()
        engine.tick(dt: 1)
        engine.reset()
        XCTAssertEqual(engine.offset, 0)
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(clock.stopCount, 1)
    }

    func testChangingTextResetsOffset() {
        engine.togglePlay()
        engine.tick(dt: 1)
        engine.text = "otro"
        XCTAssertEqual(engine.offset, 0)
        XCTAssertFalse(engine.isPlaying)
    }
}
