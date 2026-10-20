import React, { useEffect } from "react";
import { isRouteErrorResponse, useRouteError } from "react-router-dom";

/**
 * React Router catch-all error UI that also reports to Sentry when enabled.
 * createBrowserRouter's default boundary swallows render errors before the
 * global handlers, so we capture here explicitly.
 */
export function DashboardRouteError() {
  const error = useRouteError();

  useEffect(() => {
    if (!error) return;
    if (import.meta.env.DEV || import.meta.env.MODE === "test") return;
    if (!import.meta.env.VITE_SENTRY_DSN) return;
    void import("@sentry/react")
      .then((Sentry) => {
        const err = isRouteErrorResponse(error)
          ? new Error(`Route error ${error.status}: ${error.statusText || "unknown"}`)
          : error instanceof Error
            ? error
            : new Error(typeof error === "string" ? error : "Unknown route error");
        Sentry.captureException(err, {
          tags: { surface: "react-router" },
        });
      })
      .catch(() => {
        /* never break the error page */
      });
  }, [error]);

  const message = isRouteErrorResponse(error)
    ? `${error.status} ${error.statusText || ""}`.trim()
    : error instanceof Error
      ? error.message
      : "Something went wrong";

  return (
    <div style={{ padding: 24, fontFamily: "system-ui, sans-serif" }}>
      <h1 style={{ fontSize: 18, margin: "0 0 8px" }}>Something went wrong</h1>
      <p style={{ margin: 0, opacity: 0.75 }}>{message}</p>
    </div>
  );
}
