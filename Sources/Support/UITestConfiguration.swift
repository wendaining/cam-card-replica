import Foundation

/// Launch-argument driven configuration.
///
/// XCUITest cannot tap the system camera or type into a permission alert
/// reliably, so the app supports a deterministic "fixture" mode. This is the
/// mechanism behind T03–T08 in CI; the production path is untouched.
struct UITestConfiguration: Sendable {
    var isUITesting: Bool
    var seedDemoData: Bool
    var useFixtureCamera: Bool
    /// Simulated permission result when running in fixture mode.
    var simulatedCameraPermission: CameraPermissionStatus?
    /// Pin one bundled fixture (by file name without extension) instead of
    /// cycling, so a test can assert on a known card.
    var fixtureName: String?

    static let production = UITestConfiguration(
        isUITesting: false,
        seedDemoData: false,
        useFixtureCamera: false,
        simulatedCameraPermission: nil,
        fixtureName: nil
    )

    static func fromProcess(_ arguments: [String] = ProcessInfo.processInfo.arguments,
                            defaults: UserDefaults = .standard) -> UITestConfiguration {
        let isUITesting = arguments.contains("-ui-testing") || defaults.bool(forKey: "ui-testing")
        let seed = defaults.bool(forKey: "seed-data")
        let fixtures = defaults.bool(forKey: "fixture-camera")
        let permissionValue = defaults.string(forKey: "camera-permission")
        return UITestConfiguration(
            isUITesting: isUITesting,
            seedDemoData: seed,
            useFixtureCamera: fixtures,
            simulatedCameraPermission: permissionValue.flatMap(CameraPermissionStatus.init(rawValue:)),
            fixtureName: defaults.string(forKey: "fixture-name")
        )
    }
}
