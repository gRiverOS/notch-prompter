import XCTest
@testable import NotchPrompter

/// Guards the string catalog: every key must be fully translated, the keys the
/// UI relies on must exist, and the catalog must actually reach the built app.
final class LocalizationTests: XCTestCase {
    /// Keys the UI passes to SwiftUI or `String(localized:)`. Add a row here when
    /// you add a user-facing string, so a missing translation fails the suite.
    static let requiredKeys = [
        "Edit Script…",
        "Show Panel",
        "Hide Panel",
        "Shortcuts",
        "%@  (unavailable)",
        "Quit",
        "Script",
        "Saved when this window closes. The panel goes back to the start.",
        "Write your script from the menu",
        "⌃⌥ Space  Play / pause",
        "⌃⌥ ↑  Speed +10",
        "⌃⌥ ↓  Speed -10",
        "⌃⌥ R  Back to start",
        "⌃⌥ T  Show / hide panel",
    ]

    static let supportedLanguages = ["en", "es"]

    private var catalog: [String: Any]!
    private var strings: [String: Any]!

    override func setUpWithError() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appending(path: "NotchPrompter/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
    }

    func testSourceLanguageIsEnglish() {
        XCTAssertEqual(catalog["sourceLanguage"] as? String, "en")
    }

    func testEveryRequiredKeyIsInTheCatalog() {
        let missing = Self.requiredKeys.filter { strings[$0] == nil }
        XCTAssertTrue(missing.isEmpty, "keys missing from the catalog: \(missing)")
    }

    func testEveryKeyIsTranslatedInEveryLanguage() throws {
        var problems: [String] = []
        for (key, entry) in strings {
            guard let entry = entry as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any] else {
                problems.append("\(key): no localizations")
                continue
            }
            for language in Self.supportedLanguages {
                guard let unit = (localizations[language] as? [String: Any])?["stringUnit"]
                        as? [String: Any] else {
                    problems.append("\(key): missing \(language)")
                    continue
                }
                if unit["state"] as? String != "translated" {
                    problems.append("\(key) [\(language)]: state is \(unit["state"] ?? "nil")")
                }
                let value = unit["value"] as? String ?? ""
                if value.isEmpty {
                    problems.append("\(key) [\(language)]: empty value")
                }
            }
        }
        XCTAssertTrue(problems.isEmpty, "incomplete translations:\n\(problems.joined(separator: "\n"))")
    }

    func testCatalogHasNoKeysTheUIDoesNotUse() {
        let extra = strings.keys.filter { !Self.requiredKeys.contains($0) }
        XCTAssertTrue(extra.isEmpty, "catalog keys no longer used by the UI: \(extra)")
    }

    /// End-to-end check: the catalog compiles into the app bundle and Spanish resolves.
    func testSpanishResolvesFromTheBuiltAppBundle() throws {
        let appBundle = Bundle(for: PrompterEngine.self)
        let path = try XCTUnwrap(
            appBundle.path(forResource: "es", ofType: "lproj"),
            "es.lproj is missing from the app bundle"
        )
        let spanish = try XCTUnwrap(Bundle(path: path))
        XCTAssertEqual(spanish.localizedString(forKey: "Quit", value: nil, table: nil), "Salir")
        XCTAssertEqual(
            spanish.localizedString(forKey: "Write your script from the menu", value: nil, table: nil),
            "Escribe tu guion desde el menú"
        )
    }
}
