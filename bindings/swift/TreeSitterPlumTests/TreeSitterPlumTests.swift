import XCTest
import SwiftTreeSitter
import TreeSitterPlum

final class TreeSitterPlumTests: XCTestCase {
    func testCanLoadGrammar() throws {
        let parser = Parser()
        let language = Language(language: tree_sitter_plum())
        XCTAssertNoThrow(try parser.setLanguage(language),
                         "Error loading Plumlang grammar")
    }
}
