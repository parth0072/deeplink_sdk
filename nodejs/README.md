# Deeplink Node.js SDK

Server-side SDK for creating deep links, tracking events, and fetching analytics — for use in Node.js backends, serverless functions, and scripts.

## Requirements

- Node.js 18+ (uses built-in `fetch`)

## Installation

```bash
npm install @deeplink/node
```

## Quick Start

```ts
import { DeeplinkClient } from '@deeplink/node';

const client = new DeeplinkClient({
  apiKey: 'your-app-api-key',
  baseUrl: 'https://dl.yourapp.com',
});

// Create a link
const link = await client.createLink({
  destinationUrl: 'https://yourapp.com/product/123',
  iosUrl: 'myapp://product/123',
  androidUrl: 'myapp://product/123',
  params: { product_id: '123', promo: 'launch10' },
  utmSource: 'email',
  utmCampaign: 'spring-launch',
});

console.log(link.url); // https://dl.yourapp.com/abc123
```

## API

### `new DeeplinkClient(config)`

| Field | Type | Description |
|-------|------|-------------|
| `apiKey` | `string` | App API key from the Deeplink dashboard |
| `baseUrl` | `string` | Base URL of your Deeplink backend |

### `createLink(input)`

Create a new deep link. Returns `{ id, url, alias }`.

| Field | Type | Description |
|-------|------|-------------|
| `destinationUrl` | `string` | Fallback web URL |
| `iosUrl` | `string?` | iOS deep link (`myapp://...`) |
| `androidUrl` | `string?` | Android deep link |
| `alias` | `string?` | Custom short slug |
| `title` | `string?` | OG title for link previews |
| `description` | `string?` | OG description |
| `params` | `Record<string,string>?` | Metadata passed through to `getInitData()` |
| `utmSource/Medium/Campaign` | `string?` | UTM attribution |
| `expiresAt` | `string?` | ISO-8601 expiry |

### `getLink(id)` / `listLinks()` / `deleteLink(id)`

Standard CRUD for links.

### `getAnalytics(linkId, { from?, to? })`

Returns click/install time-series for a link.

```ts
const stats = await client.getAnalytics('link-id', {
  from: '2024-01-01',
  to:   '2024-01-31',
});
// { clicks, installs, unique_clicks, time_series: [{ date, clicks, installs }] }
```

### `track(event, properties?, sessionId?)`

Track a server-side event.

```ts
await client.track('purchase', { amount: 49.99, currency: 'USD' });
```
