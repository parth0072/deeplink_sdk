# Node.js Sample

Two examples demonstrating Deeplink SDK usage in Node.js.

## Setup

```bash
cd samples/nodejs-sample
npm install
```

## Demo Script

Runs through every SDK method — create link, get link, list links, analytics, event tracking:

```bash
npm run demo
```

Expected output:

```
Deeplink Node.js SDK Demo

── Create Link ──
  ✅ link.url: "https://dl.yourapp.com/abc123"
  ...

── Event Tracking ──
  ✅ Tracked: button_tapped
  ✅ Tracked: purchase
  ✅ Tracked: signup

Demo complete.
```

## Express Server

A minimal REST server that exposes link creation and analytics over HTTP — useful as a reference for integrating the SDK into your existing backend:

```bash
npm run server
# → http://localhost:3002
```

Endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/links` | Create a deep link |
| `GET` | `/links/:id/stats` | Get click/install analytics |
| `POST` | `/events` | Track a server-side event |

Example:

```bash
curl -X POST http://localhost:3002/links \
  -H "Content-Type: application/json" \
  -d '{"productId":"abc123","utmCampaign":"launch"}'
# → {"url":"https://dl.yourapp.com/abc123","alias":"abc123"}
```

## Credentials

Edit `src/demo.ts` and `src/server.ts` to set your own API key and domain:

```ts
const client = new DeeplinkClient({
  apiKey: 'your-api-key',
  baseUrl: 'https://your-backend.com',
});
```
