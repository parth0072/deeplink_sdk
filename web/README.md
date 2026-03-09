# Deeplink Web SDK

Browser SDK for deferred deep linking, link creation, and event tracking. Works via CDN `<script>` tag or as an npm module.

## Via CDN

```html
<script src="https://unpkg.com/@deeplink/web/dist/deeplink.min.js"></script>
<script>
  Deeplink.configure({ apiKey: 'your-key', domain: 'https://dl.yourapp.com' });

  // Track page view
  Deeplink.track('page_view', { page: location.pathname });

  // Fetch deferred deep link data (e.g. to personalise the landing page)
  Deeplink.getInitData().then(data => {
    if (data?.metadata?.promo) showPromo(data.metadata.promo);
  });
</script>
```

## Via npm

```bash
npm install @deeplink/web
```

```ts
import Deeplink from '@deeplink/web';

Deeplink.configure({ apiKey: 'your-key', domain: 'https://dl.yourapp.com' });
```

## API

### `Deeplink.configure({ apiKey, domain })`

Initialize the SDK. Call once before any other method. Automatically captures UTM parameters from the current URL.

### `Deeplink.getInitData({ force? })`

Fetch deferred deep link data for the current visitor. Uses browser fingerprinting to match a web click to an app install.

Returns `DeeplinkData | null`.

```ts
const data = await Deeplink.getInitData();
if (data) {
  const productId = data.metadata?.product_id;
  // Personalise the page
}
```

### `Deeplink.createLink(input)`

Create a short deep link from the browser (e.g. for a share button).

```ts
const link = await Deeplink.createLink({
  destinationUrl: 'https://yourapp.com/product/123',
  iosUrl: 'myapp://product/123',
  androidUrl: 'myapp://product/123',
  params: { product_id: '123' },
  utmSource: 'share_button',
  utmCampaign: 'viral',
});
navigator.clipboard.writeText(link.url);
```

### `Deeplink.track(event, properties?)`

Track a custom event from the browser.

```ts
await Deeplink.track('cta_click', { button: 'download', page: 'home' });
await Deeplink.track('purchase', { amount: 49.99, currency: 'USD' });
```

### `Deeplink.resetInitState()`

Clear the "already fetched" flag (for testing).

## Journeys (Smart Banner)

To show a smart app-install banner on mobile web, use the Journeys snippet from your admin dashboard instead of this SDK directly.

```html
<!-- Journeys smart banner — paste from Admin → Journeys → Embed -->
<script src="https://dl.yourapp.com/journeys.js?api_key=your-key"></script>
```
