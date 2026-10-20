import { isNativeEmbed, isNativeLinuxApp, isNativeWindowsApp } from "./native-bridge.js";

/**
 * Optional Sentry error reporting for the dashboard (hosted web + CLI localhost
 * + macOS / Windows / Linux WebViews).
 *
 * Privacy contract (keep in sync with docs/PRIVACY.md and src/lib/sentry.js):
 * - Off unless VITE_SENTRY_DSN is set at build time (public client DSN).
 * - Disabled in Vite DEV / vitest.
 * - On localhost / native surfaces, consults
 *   /functions/tokentracker-telemetry-pref first (fail-closed), matching
 *   PostHog analytics so TOKENTRACKER_NO_TELEMETRY / DO_NOT_TRACK /
 *   config `"telemetry": false` turn off error reporting too.
 * - Errors only — no Session Replay, no tracing sample by default.
 * - beforeSend scrubs common secret patterns.
 */

const SECRET_PATTERN =
  /(?:api[_-]?key|access[_-]?token|refresh[_-]?token|cookie|secret|password|dsn)[=:\s]+["']?[^\s"'\\]{8,}/gi;
const BEARER_PATTERN = /\bBearer\s+[A-Za-z0-9._~+/=-]{8,}/gi;
const JWT_PATTERN = /\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9._-]{10,}\.[A-Za-z0-9._-]{10,}\b/g;

function scrubString(value) {
  if (typeof value !== "string" || !value) return value;
  return value
    .replace(BEARER_PATTERN, "Bearer [Filtered]")
    .replace(JWT_PATTERN, "[Filtered]")
    .replace(SECRET_PATTERN, "[Filtered]");
}

function scrubValue(value, depth = 0) {
  if (depth > 6 || value == null) return value;
  if (typeof value === "string") return scrubString(value);
  if (Array.isArray(value)) return value.map((item) => scrubValue(item, depth + 1));
  if (typeof value === "object") {
    const out = {};
    for (const [key, nested] of Object.entries(value)) {
      const lower = key.toLowerCase();
      if (
        lower.includes("authorization") ||
        lower.includes("cookie") ||
        lower.includes("password") ||
        lower.includes("secret") ||
        lower.includes("token") ||
        lower.includes("api_key") ||
        lower.includes("apikey")
      ) {
        out[key] = "[Filtered]";
      } else {
        out[key] = scrubValue(nested, depth + 1);
      }
    }
    return out;
  }
  return value;
}

export function scrubEvent(event) {
  if (!event || typeof event !== "object") return event;
  const next = { ...event };
  if (next.message) next.message = scrubString(next.message);
  if (next.extra) next.extra = scrubValue(next.extra);
  if (next.contexts) next.contexts = scrubValue(next.contexts);
  if (next.request) next.request = scrubValue(next.request);
  if (Array.isArray(next.breadcrumbs)) {
    next.breadcrumbs = next.breadcrumbs.map((crumb) => scrubValue(crumb));
  }
  if (next.exception?.values) {
    next.exception = {
      ...next.exception,
      values: next.exception.values.map((item) => ({
        ...item,
        value: scrubString(item?.value),
      })),
    };
  }
  if (next.user) {
    next.user = { id: typeof next.user.id === "string" ? next.user.id : undefined };
  }
  return next;
}

export function resolveSentryShell() {
  if (typeof window === "undefined") return "web";
  if (isNativeEmbed()) return "mac-app";
  if (isNativeWindowsApp()) return "win-app";
  if (isNativeLinuxApp()) return "linux-app";
  const host = window.location.hostname;
  if (host === "localhost" || host === "127.0.0.1") return "cli-localhost";
  return "web";
}

function resolveDsn() {
  const raw = import.meta.env.VITE_SENTRY_DSN;
  return typeof raw === "string" ? raw.trim() : "";
}

function resolveRelease() {
  const version = import.meta.env.VITE_APP_VERSION || import.meta.env.APP_VERSION || "";
  const trimmed = String(version).trim();
  return trimmed ? `tokentracker@${trimmed}` : undefined;
}

async function startSentry(shell) {
  const dsn = resolveDsn();
  if (!dsn) return;
  const Sentry = await import("@sentry/react");
  Sentry.init({
    dsn,
    environment: import.meta.env.PROD ? "production" : "development",
    release: resolveRelease(),
    sendDefaultPii: false,
    tracesSampleRate: 0,
    integrations: [],
    beforeSend(event) {
      return scrubEvent(event);
    },
    initialScope: {
      tags: {
        shell,
        runtime: "browser",
      },
    },
  });
}

/**
 * Fire-and-forget Sentry init. Never throws into the app.
 */
export function initSentry() {
  if (typeof window === "undefined") return;
  if (import.meta.env.DEV || import.meta.env.MODE === "test") return;
  if (!resolveDsn()) return;

  try {
    const shell = resolveSentryShell();
    if (shell === "web") {
      void startSentry(shell).catch(() => {
        /* sentry must never break the app */
      });
      return;
    }
    fetch("/functions/tokentracker-telemetry-pref")
      .then((res) => (res.ok ? res.json() : null))
      .then((pref) => {
        if (pref && pref.disabled === false) {
          return startSentry(shell);
        }
        return undefined;
      })
      .catch(() => {
        /* preference unknown → sentry stays off */
      });
  } catch {
    /* sentry must never break the app */
  }
}
