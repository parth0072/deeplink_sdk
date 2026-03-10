# Deeplink Node.js SDK

Server-side TypeScript SDK for creating deep links, tracking events, and fetching analytics. For use in Node.js backends, serverless functions, and scripts.

← [Back to main SDK docs](../README.md)

---

## Requirements

| | Minimum |
|-|---------|
| Node.js | 18+ (uses built-in `fetch`) |
| TypeScript | 5.0+ (optional, types included) |

---

## Installation

```bash
npm install @deeplink/node
```

---

## Setup

```ts
import { DeeplinkClient } from '@deeplink/node';

const client = new DeeplinkClient({
  apiKey:  'your-app-api-key',
  baseUrl: 'https://dl.yourapp.com',
});
```

---

## Create Links

Generate short deep links server-side — e.g. in email campaigns, referral flows, or CMS integrations.

```ts
const link = await client.createLink({
  destinationUrl: 'https://yourapp.com/product/123',
  iosUrl:         'myapp://product/123',
  androidUrl:     'myapp://product/123',
  params:         { product_id: '123', promo: 'launch10' },
  title:          'Check this out',
  utmSource:      'email',
  utmMedium:      'campaign',
  utmCampaign:    'spring-launch',
  alias:          'spring-deal',   // optional custom slug
  expiresAt:      '2026-06-01T00:00:00Z',  // optional
});

console.log(link.url);   // https://dl.yourapp.com/spring-deal
console.log(link.alias); // spring-deal
```

---

## Event Tracking

Track server-side events — purchases, webhooks, backend conversions.

```ts
await client.track('purchase', {
  amount:   49.99,
  currency: 'USD',
  order_id: 'ord-123',
});

await client.track('signup', { method: 'email' });
```

---

## Link Management

```ts
// Get a single link
const link = await client.getLink('link-id');

// List all links for this app
const links = await client.listLinks();

// Delete a link
await client.deleteLink('link-id');
```

---

## Analytics

```ts
const stats = await client.getAnalytics('link-id', {
  from: '2026-01-01',
  to:   '2026-01-31',
});

// stats.clicks       — total clicks
// stats.installs     — attributed installs
// stats.unique_clicks
// stats.time_series  — [{ date, clicks, installs }]
```

---

## API Reference

| Method | Description |
|--------|-------------|
| `new DeeplinkClient({ apiKey, baseUrl })` | Create a client instance |
| `client.createLink(input)` | Create a short deep link |
| `client.getLink(id)` | Fetch a link by ID |
| `client.listLinks()` | List all links |
| `client.deleteLink(id)` | Delete a link |
| `client.getAnalytics(linkId, { from?, to? })` | Click/install time-series |
| `client.track(event, properties?, sessionId?)` | Track a server-side event |

### `CreateLinkInput`

| Field | Type | Description |
|-------|------|-------------|
| `destinationUrl` | `string` | **Required.** Fallback web URL |
| `iosUrl` | `string?` | iOS deep link (`myapp://...`) |
| `androidUrl` | `string?` | Android deep link |
| `alias` | `string?` | Custom short slug |
| `title` | `string?` | OG title for link previews |
| `description` | `string?` | OG description |
| `params` | `Record<string,string>?` | Metadata returned via `getInitData()` |
| `utmSource/Medium/Campaign` | `string?` | UTM attribution |
| `expiresAt` | `string?` | ISO-8601 expiry timestamp |

---

## Sample

[`samples/nodejs-sample/`](../samples/nodejs-sample/) — demo script + Express server example.

```bash
cd samples/nodejs-sample
npm install
npm run demo    # createLink + track against live backend
npm run server  # Express API on :3002
```
