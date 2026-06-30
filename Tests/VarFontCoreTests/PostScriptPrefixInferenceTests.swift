import XCTest
@testable import VarFontCore

final class PostScriptPrefixInferenceTests: XCTestCase {
    func testPrefersNameID25() {
        let result = PostScriptPrefixInference.infer(
            nameID25: "NouveauLEDVariable",
            postscriptName: "Milgram-Variable",
            familyName: "Milgram"
        )
        XCTAssertEqual(result, "NouveauLEDVariable")
    }

    func testUsesPostScriptStemBeforeHyphen() {
        let result = PostScriptPrefixInference.infer(
            nameID25: nil,
            postscriptName: "Milgram-Variable",
            familyName: "Milgram"
        )
        XCTAssertEqual(result, "Milgram")
    }

    func testWholePostScriptNameWhenNoHyphen() {
        let result = PostScriptPrefixInference.infer(
            nameID25: nil,
            postscriptName: "MilgramVariable",
            familyName: "Milgram"
        )
        XCTAssertEqual(result, "MilgramVariable")
    }

    func testRejectsInvalidPostScriptCharacters() {
        let result = PostScriptPrefixInference.infer(
            nameID25: nil,
            postscriptName: "Bad?.Name-Regular",
            familyName: "Milgram"
        )
        XCTAssertEqual(result, "Milgram")
    }
}
