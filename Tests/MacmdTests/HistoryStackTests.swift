import XCTest
@testable import Macmd

final class HistoryStackTests: XCTestCase {

    private func url(_ p: String) -> URL { URL(fileURLWithPath: p) }

    func test_backForwardRoundTrip() {
        let h = HistoryStack()
        let a = url("/a"), b = url("/b"), c = url("/c")

        h.visit(b, from: a)
        h.visit(c, from: b)
        XCTAssertTrue(h.canBack)
        XCTAssertFalse(h.canForward)

        XCTAssertEqual(h.goBack(current: c), b)
        XCTAssertEqual(h.goBack(current: b), a)
        XCTAssertFalse(h.canBack)
        XCTAssertTrue(h.canForward)

        XCTAssertEqual(h.goForward(current: a), b)
        XCTAssertEqual(h.goForward(current: b), c)
        XCTAssertFalse(h.canForward)
    }

    func test_visitClearsForward() {
        let h = HistoryStack()
        let a = url("/a"), b = url("/b"), c = url("/c")
        h.visit(b, from: a)
        _ = h.goBack(current: b)          // now at a, forward=[b]
        XCTAssertTrue(h.canForward)
        h.visit(c, from: a)               // new navigation clears forward
        XCTAssertFalse(h.canForward)
    }

    func test_visitSameURLIsNoop() {
        let h = HistoryStack()
        let a = url("/a")
        h.visit(a, from: a)
        XCTAssertFalse(h.canBack)
    }

    func test_goBackEmptyReturnsNil() {
        let h = HistoryStack()
        XCTAssertNil(h.goBack(current: url("/a")))
        XCTAssertNil(h.goForward(current: url("/a")))
    }
}
