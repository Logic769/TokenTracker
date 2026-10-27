import XCTest

final class DynamicIslandPlacementPolicyTests: XCTestCase {
    func testDefaultsToIslandAndRoundTrips() throws {
        let suiteName = "DynamicIslandPlacementPolicyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(DynamicIslandPlacementPolicy.placement(from: defaults), .island)

        DynamicIslandPlacementPolicy.write(.edge, to: defaults)
        XCTAssertEqual(DynamicIslandPlacementPolicy.placement(from: defaults), .edge)

        DynamicIslandPlacementPolicy.write(.island, to: defaults)
        XCTAssertEqual(DynamicIslandPlacementPolicy.placement(from: defaults), .island)
    }

    func testBridgeParsingFallsBackToIsland() {
        XCTAssertEqual(DynamicIslandPlacement.fromBridge(nil), .island)
        XCTAssertEqual(DynamicIslandPlacement.fromBridge(""), .island)
        XCTAssertEqual(DynamicIslandPlacement.fromBridge("nope"), .island)
        XCTAssertEqual(DynamicIslandPlacement.fromBridge("edge"), .edge)
        XCTAssertEqual(DynamicIslandPlacement.fromBridge("island"), .island)
        XCTAssertEqual(DynamicIslandPlacement.edge.bridgeValue, "edge")
    }

    func testCollapsedMetricsAndWingRules() {
        XCTAssertTrue(DynamicIslandPlacementPolicy.showsCollapsedMetrics(for: .island))
        XCTAssertFalse(DynamicIslandPlacementPolicy.showsCollapsedMetrics(for: .edge))
        XCTAssertTrue(DynamicIslandPlacementPolicy.appliesWingMetrics(for: .island))
        XCTAssertFalse(DynamicIslandPlacementPolicy.appliesWingMetrics(for: .edge))
        XCTAssertTrue(DynamicIslandPlacementPolicy.compactModeApplies(for: .island))
        XCTAssertFalse(DynamicIslandPlacementPolicy.compactModeApplies(for: .edge))
        XCTAssertTrue(DynamicIslandPlacementPolicy.prefersNotchedScreen(for: .island))
        XCTAssertFalse(DynamicIslandPlacementPolicy.prefersNotchedScreen(for: .edge))
    }

    func testEdgeCollapsedSizeIsFixedPill() {
        let size = DynamicIslandPlacementPolicy.edgeCollapsedSize()
        XCTAssertEqual(size.width, DynamicIslandPlacementPolicy.edgePillDepth)
        XCTAssertEqual(size.height, DynamicIslandPlacementPolicy.edgePillLength)
        XCTAssertGreaterThan(size.height, size.width)
    }

    func testEdgePanelFramePinsToRightEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let frame = DynamicIslandPlacementPolicy.edgePanelFrame(
            screenFrame: screen,
            visibleBottom: 40,
            panelWidth: 536
        )
        XCTAssertEqual(frame.maxX, screen.maxX)
        XCTAssertEqual(frame.maxY, screen.maxY)
        XCTAssertEqual(frame.width, 536)
        XCTAssertEqual(frame.height, DynamicIslandLayoutPolicy.panelHeight(screenTop: 900, visibleBottom: 40))
    }

    func testEdgeHitRectIsTrailingCollapsedPill() {
        let panel = CGSize(width: 536, height: 800)
        let collapsed = DynamicIslandPlacementPolicy.edgeCollapsedSize()
        let rect = DynamicIslandPlacementPolicy.edgeHitRect(
            panelSize: panel,
            isExpanded: false,
            collapsedSize: collapsed,
            expandedWidth: 480,
            expandedHeight: 400
        )
        XCTAssertEqual(rect.maxX, panel.width)
        XCTAssertEqual(rect.maxY, panel.height)
        XCTAssertEqual(rect.width, DynamicIslandPlacementPolicy.edgeHotZoneDepth)
        XCTAssertEqual(rect.height, collapsed.height)
    }

    func testEdgeHitRectExpandedUsesTrailingCard() {
        let panel = CGSize(width: 536, height: 800)
        let collapsed = DynamicIslandPlacementPolicy.edgeCollapsedSize()
        let rect = DynamicIslandPlacementPolicy.edgeHitRect(
            panelSize: panel,
            isExpanded: true,
            collapsedSize: collapsed,
            expandedWidth: 480,
            expandedHeight: 420
        )
        XCTAssertEqual(rect.maxX, panel.width)
        XCTAssertEqual(rect.maxY, panel.height)
        XCTAssertEqual(rect.width, 480)
        XCTAssertEqual(rect.height, 420)
    }
}
