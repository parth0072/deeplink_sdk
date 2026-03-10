# Deeplink Web SDK

Browser TypeScript/JavaScript SDK for deferred deep linking, link creation, and event tracking. Works via CDN `<script>` tag or as an npm module (ESM/CJS).

← [Back to main SDK docs](../README.md)

---

## Requirements

| | |
|-|-|
| Browser support | All modern browsers (Chrome, Safari, Firefox, Edge) |
| ES target | ES2017+ |

---

## Installation

### CDN (no build step)

```html
<script src="https://dl.yourapp.com/web/deeplink.min.js"></script>
```

Exposes `window.Deeplink` globally.

### npm

```bash
npm install @deeplink/web
```

```ts
import Deeplink from '@deeplink/web';
```

---

## Setup

Call `configure` once — before any other method. Automatically captures UTM parameters from the current URL into `sessionStorage`.

```js
Deeplink.configure({
  apiKey: 'your-app-api-key',
  domain: 'https://dl.yourapp.com',
});
```

---

## Deferred Deep Linking

Identify visitors who arrived via a Deeplink URL, and personalise the page accordingly.

```js
const data = await Deeplink.getInitData();
if (data) {
  // data.destinationUrl — the original link's destination
  // data.metadata       — { product_id, promo, ... }

  const promo = data.metadata?.promo;
  if (promo) showPromoBanner(promo);
}

// Force re-fetch (e.g. for testing)
await Deeplink.getInitData({ force: true });

// Reset the one-time guard
Deeplink.resetInitState();
```

Uses `crypto.subtle` SHA-256 browser fingerprinting (djb2 fallback) to correlate a web visit with a subsequent app install.

---

## Create Links

Generate short deep links from the browser — e.g. in share buttons or referral flows.

```js
const link = await Deeplink.createLink({
  destinationUrl: 'https://yourapp.com/product/123',
  iosUrl:         'myapp://product/123',
  androidUrl:     'myapp://product/123',
  params:         { product_id: '123', promo: 'launch10' },
  title:          'Check this out',
  utmSource:      'share_button',
  utmCampaign:    'referral',
});

// link.url   — "https://dl.yourapp.com/abc123"
// link.alias — "abc123"
navigator.clipboard.writeText(link.url);
```

---

## Event Tracking

Track browser-side events for funnel and cohort analysis.

```js
// Page view
await Deeplink.track('page_view', { page: location.pathname });

// CTA click
await Deeplink.track('cta_click', { button: 'download', section: 'hero' });

// Purchase
await Deeplink.track('purchase', { amount: 49.99, currency: 'USD' });
```

Fire-and-forget — errors are swallowed silently so tracking never breaks the page.

---

## Journeys (Smart Banner)

To show a mobile app-install banner on your web page, use the Journeys embed from Admin → Journeys instead of this SDK:

```html
<script src="https://dl.yourapp.com/journeys.js?api_key=your-key"></script>
```

---

## API Reference

| Method | Returns | Description |
|--------|---------|-------------|
| `Deeplink.configure({ apiKey, domain })` | `void` | Initialize SDK + capture UTM params |
| `Deeplink.getInitData({ force? })` | `Promise<DeeplinkData \| null>` | Fetch deferred deep link for this visitor |
| `Deeplink.createLink(input)` | `Promise<CreatedLink>` | Create a short deep link |
| `Deeplink.track(event, properties?)` | `Promise<void>` | Track a browser-side event |
| `Deeplink.resetInitState()` | `void` | Reset init guard |

### Build outputs

| File | Format | Use case |
|------|--------|----------|
| `dist/deeplink.min.js` | UMD/IIFE | CDN `<script>` tag, `window.Deeplink` global |
| `dist/deeplink.esm.js` | ESM | `import Deeplink from '@deeplink/web'` |
| `dist/deeplink.cjs.js` | CJS | `require('@deeplink/web')` |

---

## Sample Page

[`samples/web-sample/`](../samples/web-sample/) — single-page HTML demo, no build step required.

```bash
open samples/web-sample/index.html
# or
npx serve samples/web-sample
```
