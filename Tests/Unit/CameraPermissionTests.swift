@testable import CamCardReplica
import XCTest

final class CameraPermissionTests: XCTestCase {
    func testStubReportsInjectedStatus() {
        XCTAssertEqual(StubCameraPermission(status: .denied).currentStatus(), .denied)
        XCTAssertEqual(StubCameraPermission(status: .authorized).currentStatus(), .authorized)
    }

    func testStubRequestDoesNotChangeState() async {
        let stub = StubCameraPermission(status: .denied)
        let result = await stub.requestAccess()
        XCTAssertEqual(result, .denied, "T03 relies on the stub being deterministic")
    }

    func testOnlyAuthorizedAllowsTheCamera() {
        XCTAssertTrue(CameraPermissionStatus.authorized.canUseCamera)
        for status: CameraPermissionStatus in [.denied, .restricted, .notDetermined] {
            XCTAssertFalse(status.canUseCamera, "\(status) must not enable the shutter")
        }
    }

    func testSystemProviderReturnsAKnownStatus() {
        // The real status depends on the host, but it must always be a known case.
        let status = SystemCameraPermission().currentStatus()
        XCTAssertTrue(CameraPermissionStatus.allCasesForTesting.contains(status))
    }
}

private extension CameraPermissionStatus {
    static var allCasesForTesting: [CameraPermissionStatus] {
        [.authorized, .denied, .restricted, .notDetermined]
    }
}
