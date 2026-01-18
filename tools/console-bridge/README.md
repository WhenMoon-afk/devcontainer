# Console Log Bridge

A drop-in solution for forwarding browser console logs to your server console.
This enables AI coding agents (like Claude) to see frontend logs without
needing browser automation tools.

Based on [obra's approach](https://blog.fsck.com/2025/12/02/helping-agents-debug-webapps/).

## Quick Start

### 1. Copy the frontend shim to your project

```bash
cp ~/.local/share/devcontainer-tools/console-bridge/frontend-shim.js src/lib/console-bridge.js
```

### 2. Import it early in your app entry point

**Next.js (App Router)** - `app/layout.tsx`:
```tsx
import '@/lib/console-bridge';

export default function RootLayout({ children }) {
  // ...
}
```

**Vite/React** - `main.tsx`:
```tsx
import './lib/console-bridge';
import React from 'react';
// ...
```

### 3. Add the backend endpoint

Copy the relevant endpoint from `backend-endpoints.js` to your project.

**Next.js App Router** - Create `app/api/logs/route.ts`:
```typescript
import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  if (process.env.NODE_ENV === 'production') {
    return NextResponse.json({ error: 'Not available' }, { status: 404 });
  }

  const { logs } = await request.json();

  for (const log of logs) {
    const prefix = `[BROWSER:${log.level.toUpperCase()}]`;
    console.log(prefix, ...log.args.map((a: any) =>
      typeof a === 'object' ? JSON.stringify(a, null, 2) : a
    ));
  }

  return NextResponse.json({ ok: true });
}
```

## How It Works

1. **Frontend shim** intercepts `console.log/warn/error/info/debug`
2. Logs are batched (100ms window) and sent to `/api/logs`
3. **Backend endpoint** receives logs and prints them with `[BROWSER:LEVEL]` prefix
4. Original console behavior is preserved (logs still appear in browser)

## Output Example

```
[BROWSER:LOG] User clicked button, id: 123
[BROWSER:ERROR] {
  "__type": "Error",
  "message": "Failed to fetch user",
  "stack": "Error: Failed to fetch user\n    at UserProfile (UserProfile.tsx:42)"
}
[BROWSER:WARN] Deprecated API usage detected
```

## Features

- Batches logs to reduce HTTP requests
- Handles circular references and DOM nodes
- Captures unhandled errors and promise rejections
- Only runs in development mode
- Silently fails if backend is unavailable (no infinite loops)

## Customization

Edit `frontend-shim.js` to change:
- `ENDPOINT` - API path (default: `/api/logs`)
- `BATCH_INTERVAL` - Batching delay in ms (default: `100`)
- `MAX_BATCH_SIZE` - Max logs per request (default: `20`)
