/**
 * Console Log Bridge - Backend Endpoint Examples
 *
 * These are drop-in endpoint handlers for common frameworks.
 * They receive logs from the frontend shim and output them to the server console.
 *
 * Pick the one that matches your framework and add it to your project.
 */

// =============================================================================
// NEXT.JS (App Router) - app/api/logs/route.ts
// =============================================================================
/*
import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  // Only allow in development
  if (process.env.NODE_ENV === 'production') {
    return NextResponse.json({ error: 'Not available' }, { status: 404 });
  }

  try {
    const { logs } = await request.json();

    for (const log of logs) {
      const prefix = `[BROWSER:${log.level.toUpperCase()}]`;
      const args = log.args.map((arg: any) =>
        typeof arg === 'object' ? JSON.stringify(arg, null, 2) : arg
      );
      console.log(prefix, ...args);
    }

    return NextResponse.json({ ok: true });
  } catch (e) {
    return NextResponse.json({ error: 'Invalid request' }, { status: 400 });
  }
}
*/

// =============================================================================
// NEXT.JS (Pages Router) - pages/api/logs.ts
// =============================================================================
/*
import type { NextApiRequest, NextApiResponse } from 'next';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  if (process.env.NODE_ENV === 'production') {
    return res.status(404).json({ error: 'Not available' });
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { logs } = req.body;

    for (const log of logs) {
      const prefix = `[BROWSER:${log.level.toUpperCase()}]`;
      const args = log.args.map((arg: any) =>
        typeof arg === 'object' ? JSON.stringify(arg, null, 2) : arg
      );
      console.log(prefix, ...args);
    }

    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ error: 'Invalid request' });
  }
}
*/

// =============================================================================
// EXPRESS.JS
// =============================================================================
/*
// Add to your Express app:

app.post('/api/logs', express.json(), (req, res) => {
  if (process.env.NODE_ENV === 'production') {
    return res.status(404).json({ error: 'Not available' });
  }

  try {
    const { logs } = req.body;

    for (const log of logs) {
      const prefix = `[BROWSER:${log.level.toUpperCase()}]`;
      const args = log.args.map(arg =>
        typeof arg === 'object' ? JSON.stringify(arg, null, 2) : arg
      );
      console.log(prefix, ...args);
    }

    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ error: 'Invalid request' });
  }
});
*/

// =============================================================================
// HONO (Cloudflare Workers, Deno, Bun)
// =============================================================================
/*
import { Hono } from 'hono';

const app = new Hono();

app.post('/api/logs', async (c) => {
  // Note: Cloudflare Workers don't have NODE_ENV, use a different check
  // if (c.env.ENVIRONMENT === 'production') return c.json({ error: 'Not available' }, 404);

  try {
    const { logs } = await c.req.json();

    for (const log of logs) {
      const prefix = `[BROWSER:${log.level.toUpperCase()}]`;
      const args = log.args.map((arg: any) =>
        typeof arg === 'object' ? JSON.stringify(arg, null, 2) : arg
      );
      console.log(prefix, ...args);
    }

    return c.json({ ok: true });
  } catch (e) {
    return c.json({ error: 'Invalid request' }, 400);
  }
});
*/

// =============================================================================
// FASTIFY
// =============================================================================
/*
fastify.post('/api/logs', async (request, reply) => {
  if (process.env.NODE_ENV === 'production') {
    return reply.code(404).send({ error: 'Not available' });
  }

  try {
    const { logs } = request.body as { logs: any[] };

    for (const log of logs) {
      const prefix = `[BROWSER:${log.level.toUpperCase()}]`;
      const args = log.args.map((arg: any) =>
        typeof arg === 'object' ? JSON.stringify(arg, null, 2) : arg
      );
      console.log(prefix, ...args);
    }

    return { ok: true };
  } catch (e) {
    return reply.code(400).send({ error: 'Invalid request' });
  }
});
*/

// =============================================================================
// ELYSIA (Bun)
// =============================================================================
/*
import { Elysia, t } from 'elysia';

new Elysia()
  .post('/api/logs', ({ body }) => {
    for (const log of body.logs) {
      const prefix = `[BROWSER:${log.level.toUpperCase()}]`;
      const args = log.args.map((arg: any) =>
        typeof arg === 'object' ? JSON.stringify(arg, null, 2) : arg
      );
      console.log(prefix, ...args);
    }
    return { ok: true };
  }, {
    body: t.Object({
      logs: t.Array(t.Object({
        level: t.String(),
        args: t.Array(t.Any()),
        timestamp: t.String(),
        url: t.String(),
      }))
    })
  })
  .listen(3000);
*/

// =============================================================================
// CONVEX (HTTP Actions) - convex/http.ts
// =============================================================================
/*
import { httpRouter } from 'convex/server';
import { httpAction } from './_generated/server';

const http = httpRouter();

http.route({
  path: '/api/logs',
  method: 'POST',
  handler: httpAction(async (ctx, request) => {
    const { logs } = await request.json();

    for (const log of logs) {
      const prefix = `[BROWSER:${log.level.toUpperCase()}]`;
      const args = log.args.map((arg: any) =>
        typeof arg === 'object' ? JSON.stringify(arg, null, 2) : arg
      );
      console.log(prefix, ...args);
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { 'Content-Type': 'application/json' },
    });
  }),
});

export default http;
*/

console.log('This file contains backend endpoint examples. Copy the relevant section to your project.');
