import XCTest

/// Every shipped executable declares the required-reason APIs it calls in a
/// PrivacyInfo.xcprivacy at its bundle root; App Store Connect refuses an
/// upload without them. xcodegen bundles each target folder's manifest.
final class PrivacyManifestTests: XCTestCase {
    private typealias Reasons = [String: Set<String>]

    private static let userDefaults = "NSPrivacyAccessedAPICategoryUserDefaults"
    private static let fileTimestamp = "NSPrivacyAccessedAPICategoryFileTimestamp"
    private static let bootTime = "NSPrivacyAccessedAPICategorySystemBootTime"

    /// Target folder -> the reasons its code needs.
    private static let expected: [String: Reasons] = [
        // Standard and App Group defaults, cache and staging file dates,
        // systemUptime for animation clocks and retry intervals.
        "Belay": [
            userDefaults: ["CA92.1", "1C8F.1"],
            fileTimestamp: ["C617.1"],
            bootTime: ["35F9.1"],
        ],
        // Its own defaults, call log sizes, systemUptime for audio timing.
        "BelayWatch": [
            userDefaults: ["CA92.1"],
            fileTimestamp: ["C617.1"],
            bootTime: ["35F9.1"],
        ],
        // NotificationSharedSettings reads the App Group defaults.
        "BelayNotificationService": [userDefaults: ["1C8F.1"]],
        "BelayLocationPush": [userDefaults: ["1C8F.1"]],
    ]

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // BelayTests
            .deletingLastPathComponent() // repo root
    }

    func testEachTargetManifestDeclaresItsRequiredReasons() throws {
        for (folder, reasons) in Self.expected {
            let url = Self.repoRoot.appendingPathComponent("\(folder)/PrivacyInfo.xcprivacy")
            let manifest = try Self.manifest(at: url)
            XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false, folder)
            XCTAssertEqual((manifest["NSPrivacyTrackingDomains"] as? [String])?.isEmpty, true, folder)
            XCTAssertNotNil(manifest["NSPrivacyCollectedDataTypes"] as? [Any], folder)
            XCTAssertEqual(try Self.accessedReasons(manifest), reasons, folder)
        }
    }

    func testAppBundleShipsItsManifest() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
            "Belay.app has no PrivacyInfo.xcprivacy"
        )
        XCTAssertEqual(try Self.accessedReasons(Self.manifest(at: url)), Self.expected["Belay"])
    }

    /// The CI test build (project-tests.yml) embeds no extensions or Watch
    /// app; a full build embeds them, and then each must carry its own.
    func testEmbeddedBundlesShipTheirManifests() throws {
        let app = Bundle.main.bundleURL
        let embedded = [
            ("BelayNotificationService", app.appendingPathComponent("PlugIns/BelayNotificationService.appex")),
            ("BelayLocationPush", app.appendingPathComponent("PlugIns/BelayLocationPush.appex")),
            ("BelayWatch", app.appendingPathComponent("Watch/BelayWatch.app")),
        ]
        for (folder, bundle) in embedded where FileManager.default.fileExists(atPath: bundle.path) {
            let manifest = try Self.manifest(at: bundle.appendingPathComponent("PrivacyInfo.xcprivacy"))
            XCTAssertEqual(try Self.accessedReasons(manifest), Self.expected[folder], folder)
        }
    }

    private static func manifest(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            url.path
        )
    }

    private static func accessedReasons(_ manifest: [String: Any]) throws -> Reasons {
        let entries = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        var reasons: Reasons = [:]
        for entry in entries {
            let type = try XCTUnwrap(entry["NSPrivacyAccessedAPIType"] as? String)
            let codes = try XCTUnwrap(entry["NSPrivacyAccessedAPITypeReasons"] as? [String])
            XCTAssertNil(reasons[type], "\(type) is declared twice")
            reasons[type] = Set(codes)
        }
        return reasons
    }
}
