import CoreGraphics
import Foundation

/// Where the Dynamic Island chrome lives on screen.
///
/// `.island` is the existing top-center / notch-hugging layout.
/// `.edge` is the CodeNotch-inspired right-edge fixed pill (v1: right only).
enum DynamicIslandPlacement: String, CaseIterable, Equatable {
    case island
    case edge

    var bridgeValue: String { rawValue }

    static func fromBridge(_ value: String?) -> DynamicIslandPlacement {
        guard let value, let parsed = DynamicIslandPlacement(rawValue: value) else {
            return .island
        }
        return parsed
    }
}

/// Pure preference + geometry policy for island vs edge placement.
///
/// Keeping placement math here (instead of in AppKit) makes the right-edge
/// pill sizing and panel anchoring unit-testable, and keeps the hide-menu-bar
/// icon setting orthogonal: changing icon visibility never changes these
/// numbers.
enum DynamicIslandPlacementPolicy {
    static let defaultsKey = "DynamicIslandPlacement"

    /// Depth of the collapsed right-edge pill into the screen (pt).
    /// Inspired by CodeNotch's resting pill (~9.8 pt); slightly thicker so a
    /// small brand glyph stays readable.
    static let edgePillDepth: CGFloat = 12
    /// Length of the collapsed right-edge pill along the screen edge (pt).
    static let edgePillLength: CGFloat = 80
    /// Extra wake depth beyond the visible pill so hover is forgiving.
    static let edgeHotZoneDepth: CGFloat = 28

    static func placement(from defaults: UserDefaults = .standard) -> DynamicIslandPlacement {
        DynamicIslandPlacement.fromBridge(defaults.string(forKey: defaultsKey))
    }

    static func write(_ placement: DynamicIslandPlacement, to defaults: UserDefaults = .standard) {
        defaults.set(placement.rawValue, forKey: defaultsKey)
    }

    /// Collapsed chrome must not carry variable-length metric strings in edge
    /// mode — that is the whole point of the fixed pill.
    static func showsCollapsedMetrics(for placement: DynamicIslandPlacement) -> Bool {
        placement == .island
    }

    /// Wing-width measurement only applies to the notch-hugging layout.
    static func appliesWingMetrics(for placement: DynamicIslandPlacement) -> Bool {
        placement == .island
    }

    /// Compact ring mode only makes sense on island wings.
    static func compactModeApplies(for placement: DynamicIslandPlacement) -> Bool {
        placement == .island
    }

    /// Fixed collapsed size for edge mode. Island mode keeps using notch /
    /// simulated geometry from the controller.
    static func edgeCollapsedSize() -> CGSize {
        CGSize(width: edgePillDepth, height: edgePillLength)
    }

    /// Panel frame for edge mode: same generous size as the island panel, but
    /// pinned to the right edge of the screen so expand grows leftward.
    static func edgePanelFrame(
        screenFrame: CGRect,
        visibleBottom: CGFloat,
        panelWidth: CGFloat
    ) -> CGRect {
        let panelHeight = DynamicIslandLayoutPolicy.panelHeight(
            screenTop: screenFrame.maxY,
            visibleBottom: visibleBottom
        )
        let width = max(panelWidth, DynamicIslandLayoutPolicy.expandedWidth)
        return CGRect(
            x: screenFrame.maxX - width,
            y: screenFrame.maxY - panelHeight,
            width: width,
            height: panelHeight
        )
    }

    /// Interactive rect of the black shape in panel coordinates (origin
    /// bottom-left). Collapsed: trailing vertical pill near the top.
    /// Expanded: trailing card matching the measured island height.
    static func edgeHitRect(
        panelSize: CGSize,
        isExpanded: Bool,
        collapsedSize: CGSize,
        expandedWidth: CGFloat,
        expandedHeight: CGFloat
    ) -> CGRect {
        let width: CGFloat
        let height: CGFloat
        if isExpanded {
            width = min(max(expandedWidth, collapsedSize.width), panelSize.width)
            height = min(max(expandedHeight, collapsedSize.height), panelSize.height)
        } else {
            // Hot zone is a bit deeper than the visible pill for easier hover.
            width = min(max(collapsedSize.width, edgeHotZoneDepth), panelSize.width)
            height = min(collapsedSize.height, panelSize.height)
        }
        let x = panelSize.width - width
        let y = panelSize.height - height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Prefer the main / cursor screen in edge mode; island mode still prefers
    /// a hardware-notched screen when available.
    static func prefersNotchedScreen(for placement: DynamicIslandPlacement) -> Bool {
        placement == .island
    }
}
