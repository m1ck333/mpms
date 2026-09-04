import * as Sentry from '@sentry/react';

export function initSentry() {
  const dsn = import.meta.env.VITE_SENTRY_DSN;
  if (!dsn) {
    // No DSN = SDK is disabled. Matches the backend pattern so dev runs
    // without sending anything to Sentry.
    return;
  }

  Sentry.init({
    dsn,
    environment: import.meta.env.VITE_SENTRY_ENVIRONMENT ?? 'development',
    release: import.meta.env.VITE_SENTRY_RELEASE,
    integrations: [
      Sentry.browserTracingIntegration(),
      Sentry.replayIntegration({ maskAllText: true, blockAllMedia: true }),
    ],
    tracesSampleRate: 0.1,
    replaysSessionSampleRate: 0.0,
    replaysOnErrorSampleRate: 1.0,
    // Benign/expected errors that are never actionable — filtered so real
    // issues aren't buried. Realtime (SignalR) churn is normal on factory
    // tablets (shift-start reconnects, sleep/wake, flaky wifi); auto-reconnect
    // + polling fallback mean a dropped realtime connection is not a user-facing bug.
    ignoreErrors: [
      'Server returned handshake error',
      'Handshake was canceled',
      'stopped during negotiation',
      'connection was stopped before the hub handshake could complete',
      'Server timeout elapsed without receiving a message',
      'ResizeObserver loop limit exceeded',
      'ResizeObserver loop completed with undelivered notifications',
    ],
    beforeSend(event) {
      if (event.breadcrumbs) {
        event.breadcrumbs.forEach((bc) => {
          if (bc.data && typeof bc.data === 'object') {
            const data = bc.data as Record<string, unknown>;
            if (data.Authorization) data.Authorization = '[Filtered]';
            if (data.Cookie) data.Cookie = '[Filtered]';
          }
        });
      }
      return event;
    },
  });
}
