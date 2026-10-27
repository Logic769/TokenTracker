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
        // CodeNotch-inspired resting proportions (~10×80), not a square tile.
        XCTAssertEqual(size.width, 10)
        XCTAssertEqual(size.height, 80)
    }

    func testEdgeShapeRadiiDifferCollapsedVsExpanded() {
        XCTAssertGreaterThan(
            DynamicIslandPlacementPolicy.edgeCurlRadius(isExpanded: false),
            DynamicIslandPlacementPolicy.edgeCurlRadius(isExpanded: true)
        )
        XCTAssertLessThan(
            DynamicIslandPlacementPolicy.edgeCornerRadius(isExpanded: false),
            DynamicIslandPlacementPolicy.edgeCornerRadius(isExpanded: true)
        )
        XCTAssertEqual(DynamicIslandPlacementPolicy.edgeCornerRadius(isExpanded: true), 22)
    }

    func testEdgePanelFramePinsToRightEdgeAndCentersVertically() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let frame = DynamicIslandPlacementPolicy.edgePanelFrame(
            screenFrame: screen,
            visibleBottom: 40,
            panelWidth: 536
        )
        let expectedHeight = DynamicIslandLayoutPolicy.panelHeight(screenTop: 900, visibleBottom: 40)
        XCTAssertEqual(frame.maxX, screen.maxX)
        XCTAssertEqual(frame.width, 536)
        XCTAssertEqual(frame.height, expectedHeight)
        // On a tall display the capped panel is vertically centered in the
        // usable strip, so mid-bezel chrome sits at true screen midY.
        let availableMidY = 40 + (900 - 40) / 2
        XCTAssertEqual(frame.midY, availableMidY, accuracy: 0.5)
        XCTAssertLessThan(frame.maxY, screen.maxY)
        XCTAssertGreaterThan(frame.minY, 40 - 0.5)
    }

    func testEdgePanelFrameFillsShortDisplays() {
        let screen = CGRect(x: 0, y: 0, width: 1_280, height: 720)
        let frame = DynamicIslandPlacementPolicy.edgePanelFrame(
            screenFrame: screen,
            visibleBottom: 40,
            panelWidth: 536
        )
        // Available height 680 < max panel — panel fills the strip.
        XCTAssertEqual(frame.minY, 40, accuracy: 0.5)
        XCTAssertEqual(frame.maxY, screen.maxY, accuracy: 0.5)
        XCTAssertEqual(frame.maxX, screen.maxX)
    }

    func testEdgeHitRectIsVerticallyCenteredTrailingPill() {
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
        XCTAssertEqual(rect.width, DynamicIslandPlacementPolicy.edgeHotZoneDepth)
        XCTAssertEqual(rect.height, collapsed.height)
        // Mid-bezel like CodeNotch — not glued to the menu bar.
        XCTAssertEqual(rect.midY, panel.height / 2, accuracy: 0.5)
        XCTAssertEqual(DynamicIslandPlacementPolicy.edgeHotZoneDepth, 36)
    }

    func testEdgeHitRectExpandedIsVerticallyCenteredTrailingCard() {
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
        XCTAssertEqual(rect.width, 480)
        XCTAssertEqual(rect.height, 420)
        XCTAssertEqual(rect.midY, panel.height / 2, accuracy: 0.5)
    }
}
