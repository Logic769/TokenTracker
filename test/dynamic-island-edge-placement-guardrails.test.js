const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

const root = path.join(__dirname, "..");
const policySource = fs.readFileSync(
  path.join(root, "TokenTrackerBar/TokenTrackerBar/Models/DynamicIslandPlacementPolicy.swift"),
  "utf8",
);
const controllerSource = fs.readFileSync(
  path.join(root, "TokenTrackerBar/TokenTrackerBar/Services/DynamicIslandController.swift"),
  "utf8",
);
const viewSource = fs.readFileSync(
  path.join(root, "TokenTrackerBar/TokenTrackerBar/Views/DynamicIslandView.swift"),
  "utf8",
);
const bridgeSource = fs.readFileSync(
  path.join(root, "TokenTrackerBar/TokenTrackerBar/Services/NativeBridge.swift"),
  "utf8",
);
const labsSource = fs.readFileSync(
  path.join(root, "dashboard/src/components/settings/LabsSection.jsx"),
  "utf8",
);

test("placement policy keeps edge collapsed metrics off and orthogonal to hide-icon", () => {
  assert.match(policySource, /showsCollapsedMetrics\(for placement: DynamicIslandPlacement\) -> Bool/);
  assert.match(policySource, /placement == \.island/);
  assert.match(policySource, /edgePillDepth/);
  assert.match(policySource, /edgePillLength/);
  assert.doesNotMatch(
    policySource,
    /hideMenuBarIcon|HideMenuBar/,
    "placement geometry must stay orthogonal to hide-menu-bar-icon",
  );
});

test("controller reloads placement and pins edge panel to the right", () => {
  assert.match(controllerSource, /func reloadPlacement\(\)/);
  assert.match(controllerSource, /state\.placement == \.edge/);
  assert.match(controllerSource, /edgePanelFrame\(/);
  assert.match(controllerSource, /edgeHitRect\(/);
  assert.match(
    controllerSource,
    /appliesWingMetrics\(for: state\.placement\)/,
    "wing width must be ignored in edge mode",
  );
});

test("view uses a fixed edge pill without collapsed metric wings", () => {
  assert.match(viewSource, /edgeCollapsedPill/);
  assert.match(viewSource, /EdgeNotchShape/);
  assert.match(viewSource, /showsCollapsedMetrics\(for: state\.placement\)/);
  assert.match(viewSource, /state\.placement == \.edge/);
  assert.doesNotMatch(
    viewSource,
    /clipShape\(Capsule\(\)\)/,
    "collapsed edge must use EdgeNotchShape, not a bare Capsule",
  );
});

test("edge flush shape needs no curl content inset", () => {
  assert.match(viewSource, /edgeContentInset/);
  assert.match(viewSource, /let edgeContentInset: CGFloat = 0/);
  assert.match(policySource, /edgeCurlExpanded: CGFloat = 0/);
  assert.match(policySource, /edgeCurlIdeal: CGFloat = 0/);
  assert.match(policySource, /edgePanelFrame/);
  // Panel must center vertically for mid-bezel placement on tall displays.
  assert.match(policySource, /\(available - height\) \/ 2/);
});

test("controller uses CodeNotch-like unfold spring for edge expand", () => {
  assert.match(controllerSource, /EdgeNotchMotion\.unfold/);
  assert.match(controllerSource, /state\.placement == \.edge/);
});

test("edge shape is right-flush rounded rect without bezel flare", () => {
  const shape = fs.readFileSync(
    path.join(root, "TokenTrackerBar/TokenTrackerBar/Views/EdgeNotchShape.swift"),
    "utf8",
  );
  assert.match(shape, /struct EdgeNotchShape/);
  assert.match(shape, /enum EdgeNotchMotion/);
  assert.match(shape, /response: 0\.62/);
  assert.match(shape, /dampingFraction: 0\.72/);
  assert.match(shape, /circleReach/);
  assert.doesNotMatch(shape, /fluidTurn/, "bezel flare / fluidTurn removed");
  assert.doesNotMatch(shape, /filletRamp/, "filletRamp removed with flare");
  assert.doesNotMatch(shape, /curlAlong/, "no along-edge ears");
  assert.doesNotMatch(shape, /curlRadius/, "curlRadius removed from shape");
  assert.match(policySource, /edgeCurlRadius/);
  assert.match(policySource, /edgeCornerRadius/);
  assert.match(policySource, /edgeCurlIdeal: CGFloat = 0/);
});

test("collapsed edge chrome has no drop shadow or stroke AA dirt", () => {
  // Collapsed must gate shadow/stroke to expanded-only (flush join stays clean).
  assert.match(viewSource, /opacity\(expanded \? 0\.28 : 0\)/);
  assert.match(viewSource, /radius: expanded \? 14 : 0/);
  assert.match(
    viewSource,
    /if expanded \{[\s\S]*?edgeShape[\s\S]*?\.stroke\(/,
    "expanded edge may keep a light rim; collapsed must not stroke",
  );
});

test("reloadPlacement refreshes fullscreen presence for the new screen", () => {
  assert.match(
    controllerSource,
    /func reloadPlacement\(\)[\s\S]*?fullscreenActive = readFullscreenActive\(\)[\s\S]*?applyPresence\(\)/,
  );
  assert.match(controllerSource, /func presenceScreen\(\) -> NSScreen\?/);
});

test("native bridge exposes and accepts dynamicIslandPlacement", () => {
  assert.match(bridgeSource, /"dynamicIslandPlacement"/);
  assert.match(bridgeSource, /case "dynamicIslandPlacement":/);
  assert.match(bridgeSource, /DynamicIslandPlacementPolicy\.write/);
});

test("Labs settings offers island vs edge segmented control", () => {
  assert.match(labsSource, /dynamicIslandPlacement/);
  assert.match(labsSource, /SegmentedControl/);
  assert.match(labsSource, /settings\.labs\.island_placement/);
});
