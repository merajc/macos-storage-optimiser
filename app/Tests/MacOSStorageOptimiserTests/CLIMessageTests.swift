import XCTest
@testable import MacOSStorageOptimiser

final class CLIMessageTests: XCTestCase {
    func testDecodesItemLine() throws {
        let line = """
        {"type":"item","id":"xcode-deriveddata","tier":2,"safety":"safe","label":"Xcode DerivedData","note":"regenerated","state":"present","bytes":7025188864,"count":1,"cleanable":true,"paths":["/Users/a/Library/Developer/Xcode/DerivedData"]}
        """
        guard case .item(let item)? = CLIMessage.decode(line) else {
            return XCTFail("expected item")
        }
        XCTAssertEqual(item.id, "xcode-deriveddata")
        XCTAssertEqual(item.tier, 2)
        XCTAssertEqual(item.safety, .safe)
        XCTAssertEqual(item.state, .present)
        XCTAssertEqual(item.bytes, 7_025_188_864)
        XCTAssertTrue(item.cleanable)
        XCTAssertEqual(item.paths.count, 1)
    }

    func testDecodesDeniedItem() throws {
        let line = """
        {"type":"item","id":"trash","tier":3,"safety":"review","label":"User Trash Bin","note":"","state":"denied","bytes":0,"count":1,"cleanable":true,"paths":["/Users/a/.Trash"]}
        """
        guard case .item(let item)? = CLIMessage.decode(line) else {
            return XCTFail("expected item")
        }
        XCTAssertEqual(item.state, .denied)
        XCTAssertEqual(item.safety, .review)
    }

    func testDecodesInsightAndCataloguedFlag() throws {
        let line = """
        {"type":"insight","kind":"heavy-cache","id":"heavy-cache:Google","label":"Google","bytes":2762403840,"path":"/Users/a/Library/Caches/Google","catalogued":false}
        """
        guard case .insight(let insight)? = CLIMessage.decode(line) else {
            return XCTFail("expected insight")
        }
        XCTAssertEqual(insight.kind, "heavy-cache")
        XCTAssertEqual(insight.catalogued, false)
    }

    func testDecodesDiskAndDoneAndClean() throws {
        let disk = #"{"type":"disk","totalBytes":494384795648,"usedBytes":362255724544,"freeBytes":97192501248,"usedPercent":79}"#
        guard case .disk(let info)? = CLIMessage.decode(disk) else {
            return XCTFail("expected disk")
        }
        XCTAssertEqual(info.usedPercent, 79)

        let done = #"{"type":"done","reclaimableBytes":20788097024,"reclaimableItems":10}"#
        guard case .done(let summary)? = CLIMessage.decode(done) else {
            return XCTFail("expected done")
        }
        XCTAssertEqual(summary.reclaimableBytes, 20_788_097_024)

        let clean = #"{"type":"clean","id":"trash","label":"User Trash Bin","status":"would-clean","bytes":2481582080,"message":""}"#
        guard case .clean(let result)? = CLIMessage.decode(clean) else {
            return XCTFail("expected clean")
        }
        XCTAssertEqual(result.status, "would-clean")
        XCTAssertEqual(result.bytes, 2_481_582_080)
    }

    func testIgnoresGarbageAndUnknownTypes() {
        XCTAssertNil(CLIMessage.decode("not json"))
        XCTAssertNil(CLIMessage.decode(#"{"type":"future-thing"}"#))
        XCTAssertNotNil(CLIMessage.decode(#"{"type":"meta","schema":1}"#))
    }

    func testDisplayRowHidesSelectionForMissingItems() {
        let item = ScanItem(
            id: "gradle", tier: 2, safety: .safe, label: "Gradle Cache", note: "",
            state: .missing, bytes: 0, count: 0, cleanable: true, paths: []
        )
        let row = DisplayRow(item: item)
        XCTAssertFalse(row.cleanable)
    }

    func testShortPathUsesTilde() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertEqual(Format.shortPath(home + "/Library/Caches"), "~/Library/Caches")
        XCTAssertEqual(Format.shortPath("/var/folders/x"), "/var/folders/x")
    }
}
