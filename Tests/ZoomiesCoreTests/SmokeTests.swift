import XCTest
@testable import ZoomiesCore

final class SmokeTests: XCTestCase {
    func testVersionIsSet() {
        XCTAssertEqual(ZoomiesInfo.version, "1.0")
    }
}
