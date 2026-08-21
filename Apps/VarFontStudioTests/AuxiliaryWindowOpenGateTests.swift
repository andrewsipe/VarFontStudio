import XCTest
@testable import VarFontStudio

final class AuxiliaryWindowOpenGateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AuxiliaryWindowOpenGate.resetForTests()
    }

    func testClaimAllowsOnlyFirstBridgeForToken() {
        let token = UUID()
        XCTAssertTrue(AuxiliaryWindowOpenGate.claim(token))
        XCTAssertFalse(AuxiliaryWindowOpenGate.claim(token))
        XCTAssertFalse(AuxiliaryWindowOpenGate.claim(token))
    }

    func testClaimAllowsDistinctTokens() {
        let first = UUID()
        let second = UUID()
        XCTAssertTrue(AuxiliaryWindowOpenGate.claim(first))
        XCTAssertTrue(AuxiliaryWindowOpenGate.claim(second))
        XCTAssertFalse(AuxiliaryWindowOpenGate.claim(first))
    }
}
