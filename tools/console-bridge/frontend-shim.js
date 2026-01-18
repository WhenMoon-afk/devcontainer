/**
 * Console Log Bridge - Frontend Shim
 *
 * Intercepts browser console.log/warn/error/info and sends them to a backend
 * endpoint so that AI agents (like Claude) can see frontend logs without
 * needing to use browser automation tools.
 *
 * Based on obra's approach: https://blog.fsck.com/2025/12/02/helping-agents-debug-webapps/
 *
 * USAGE:
 * 1. Copy this file to your project (e.g., src/lib/console-bridge.js)
 * 2. Import early in your app entry point (before other code runs)
 * 3. Set up the backend endpoint (see console-bridge-endpoints.js)
 *
 * Example (Next.js app/layout.tsx):
 *   import '@/lib/console-bridge';
 *
 * Example (Vite main.tsx):
 *   import './lib/console-bridge';
 */

(function initConsoleBridge() {
  // Only run in browser and development mode
  if (typeof window === 'undefined') return;
  if (process.env.NODE_ENV === 'production') return;

  const ENDPOINT = '/api/logs';
  const BATCH_INTERVAL = 100; // ms - batch logs to reduce requests
  const MAX_BATCH_SIZE = 20;

  let logBatch = [];
  let batchTimer = null;
  let isSending = false;

  // Store original console methods
  const originalConsole = {
    log: console.log.bind(console),
    warn: console.warn.bind(console),
    error: console.error.bind(console),
    info: console.info.bind(console),
    debug: console.debug.bind(console),
  };

  // Serialize arguments safely
  function serialize(args) {
    return args.map(arg => {
      if (arg === undefined) return 'undefined';
      if (arg === null) return 'null';
      if (arg instanceof Error) {
        return {
          __type: 'Error',
          message: arg.message,
          stack: arg.stack,
          name: arg.name
        };
      }
      if (typeof arg === 'object') {
        try {
          return JSON.parse(JSON.stringify(arg, (key, value) => {
            // Handle circular references and DOM nodes
            if (value instanceof HTMLElement) return `[HTMLElement: ${value.tagName}]`;
            if (value instanceof Window) return '[Window]';
            if (value instanceof Document) return '[Document]';
            return value;
          }));
        } catch (e) {
          return String(arg);
        }
      }
      return arg;
    });
  }

  // Send batch to backend
  async function flushBatch() {
    if (logBatch.length === 0 || isSending) return;

    const batch = logBatch.splice(0, MAX_BATCH_SIZE);
    isSending = true;

    try {
      await fetch(ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ logs: batch }),
      });
    } catch (e) {
      // CRITICAL: Do NOT try to log this error - would cause infinite loop
      // Silently fail - the original console still works
    } finally {
      isSending = false;
      // If more logs accumulated while sending, flush again
      if (logBatch.length > 0) {
        scheduleBatch();
      }
    }
  }

  function scheduleBatch() {
    if (batchTimer) return;
    batchTimer = setTimeout(() => {
      batchTimer = null;
      flushBatch();
    }, BATCH_INTERVAL);
  }

  function queueLog(level, args) {
    logBatch.push({
      level,
      args: serialize(args),
      timestamp: new Date().toISOString(),
      url: window.location.href,
    });
    scheduleBatch();
  }

  // Override console methods
  console.log = function(...args) {
    originalConsole.log(...args);
    queueLog('log', args);
  };

  console.warn = function(...args) {
    originalConsole.warn(...args);
    queueLog('warn', args);
  };

  console.error = function(...args) {
    originalConsole.error(...args);
    queueLog('error', args);
  };

  console.info = function(...args) {
    originalConsole.info(...args);
    queueLog('info', args);
  };

  console.debug = function(...args) {
    originalConsole.debug(...args);
    queueLog('debug', args);
  };

  // Also capture unhandled errors and promise rejections
  window.addEventListener('error', (event) => {
    queueLog('error', [{
      __type: 'UncaughtError',
      message: event.message,
      filename: event.filename,
      lineno: event.lineno,
      colno: event.colno,
    }]);
  });

  window.addEventListener('unhandledrejection', (event) => {
    queueLog('error', [{
      __type: 'UnhandledRejection',
      reason: event.reason instanceof Error
        ? { message: event.reason.message, stack: event.reason.stack }
        : String(event.reason),
    }]);
  });

  // Expose restore function for testing
  window.__restoreConsole = function() {
    Object.assign(console, originalConsole);
  };

  originalConsole.info('[console-bridge] Frontend logging bridge active');
})();
