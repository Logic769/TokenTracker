"use strict";

const assert = require("node:assert/strict");
const { test, beforeEach } = require("node:test");

const {
  initSentry,
  resolveDsn,
  resolveEnvironment,
  resolveShell,
  scrubEvent,
  scrubString,
  _resetForTests,
} = require("../src/lib/sentry");

beforeEach(() => {
  _resetForTests();
});

test("resolveDsn prefers TOKENTRACKER_SENTRY_DSN over SENTRY_DSN", () => {
  assert.equal(resolveDsn({}), "");
  assert.equal(resolveDsn({ SENTRY_DSN: "https://a@o.ingest.sentry.io/1" }), "https://a@o.ingest.sentry.io/1");
  assert.equal(
    resolveDsn({
      TOKENTRACKER_SENTRY_DSN: "https://b@o.ingest.sentry.io/2",
      SENTRY_DSN: "https://a@o.ingest.sentry.io/1",
    }),
    "https://b@o.ingest.sentry.io/2",
  );
});

test("resolveEnvironment and resolveShell use app tags", () => {
  assert.equal(resolveEnvironment({}), "development");
  assert.equal(resolveEnvironment({ NODE_ENV: "production" }), "production");
  assert.equal(resolveEnvironment({ TOKENTRACKER_SENTRY_ENVIRONMENT: "staging" }), "staging");
  assert.equal(resolveShell({}), "cli");
  assert.equal(resolveShell({ TOKENTRACKER_APP_SHELL: "macos" }), "macos");
  assert.equal(resolveShell({ TOKENTRACKER_APP_SHELL: "weird" }), "cli");
});

test("scrubString redacts bearer tokens and jwt-looking blobs", () => {
  assert.match(
    scrubString("Authorization: Bearer abcdefghijklmnop"),
    /Bearer \[Filtered\]/,
  );
  assert.match(
    scrubString("api_key=sk-live-abcdefghijklmnopqrstuvwxyz"),
    /\[Filtered\]/,
  );
  const jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.signaturepartxx";
  assert.equal(scrubString(`header ${jwt} tail`), "header [Filtered] tail");
});

test("scrubEvent filters sensitive keys and exception values", () => {
  const scrubbed = scrubEvent({
    message: "api_key=supersecrettokenvalue",
    extra: { access_token: "should-go", nested: { ok: true } },
    exception: { values: [{ value: "Bearer abcdefghijklmnop failed" }] },
    user: { id: "anon", email: "a@b.c", ip_address: "1.2.3.4" },
  });
  assert.match(scrubbed.message, /\[Filtered\]/);
  assert.equal(scrubbed.extra.access_token, "[Filtered]");
  assert.equal(scrubbed.extra.nested.ok, true);
  assert.match(scrubbed.exception.values[0].value, /Bearer \[Filtered\]/);
  assert.deepEqual(scrubbed.user, { id: "anon" });
});

test("initSentry is a no-op without DSN and in test runner", async () => {
  const noDsn = await initSentry({ env: { ...process.env, TOKENTRACKER_SENTRY_DSN: "", SENTRY_DSN: "" } });
  assert.equal(noDsn.enabled, false);
  assert.equal(noDsn.reason, "test-env"); // NODE_TEST_CONTEXT is set by node --test

  const optedOut = await initSentry({
    env: {
      ...process.env,
      TOKENTRACKER_SENTRY_DSN: "https://examplePublicKey@o0.ingest.sentry.io/0",
      TOKENTRACKER_NO_TELEMETRY: "1",
    },
  });
  assert.equal(optedOut.enabled, false);
  // Still test-env first because NODE_TEST_CONTEXT wins
  assert.equal(optedOut.reason, "test-env");
});

test("initSentry respects telemetry opt-out when test marker cleared", async () => {
  const env = { ...process.env };
  delete env.NODE_TEST_CONTEXT;
  env.TOKENTRACKER_SENTRY_DSN = "https://examplePublicKey@o0.ingest.sentry.io/0";
  env.TOKENTRACKER_NO_TELEMETRY = "1";
  const result = await initSentry({ env, trackerDir: null });
  assert.equal(result.enabled, false);
  assert.equal(result.reason, "opt-out");
});
