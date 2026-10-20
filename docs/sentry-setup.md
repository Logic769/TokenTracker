# Sentry setup (TokenTracker)

Org: [`tokentracker`](https://tokentracker.sentry.io/) (Sponsored Business).

## Projects to create

Create **two** projects under the org (Settings → Projects → Create Project):

| Project slug (suggested) | Platform | Used by |
|---|---|---|
| `tokentracker-dashboard` | React / JavaScript | `dashboard/` (`@sentry/react`), including desktop WebViews |
| `tokentracker-node` | Node.js | CLI + EmbeddedServer (`@sentry/node` in `src/lib/sentry.js`) |

Do **not** add native Swift / .NET / Tauri projects in v1 — those shells mostly host the dashboard + Node runtime above.

## Wire DSNs (public client keys)

After creating each project, copy its **DSN** from Project Settings → Client Keys (DSN).

| Surface | Env var | Where |
|---|---|---|
| Dashboard / WebViews | `VITE_SENTRY_DSN` | Vercel env for `www.tokentracker.cc`, and release builds that embed `dashboard/dist` |
| Node CLI / EmbeddedServer | `TOKENTRACKER_SENTRY_DSN` | Process env for local CLI; optional in desktop EmbeddedServer env |

Public DSNs are safe to embed (same model as PostHog). Until a DSN is set, Sentry stays fully off.

Optional: `TOKENTRACKER_SENTRY_ENVIRONMENT` overrides the Node environment tag (`production` / `development`).

## Auth for `sentry-cli` / API

Creating projects and uploading source maps needs an org auth token (not committed):

1. Sentry → Settings → Auth Tokens (or Custom Integrations → Internal Integration) with `project:write` + `org:read`.
2. `export SENTRY_AUTH_TOKEN=...`
3. `sentry-cli projects list -o tokentracker`

## Privacy

Sentry is covered by the same opt-out as anonymous telemetry: `TOKENTRACKER_NO_TELEMETRY=1`, `DO_NOT_TRACK=1`, or `"telemetry": false` in `config.json`. See [PRIVACY.md](./PRIVACY.md).
