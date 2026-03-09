# Web Sample

Single-page HTML demo exercising every Deeplink Web SDK feature.

## Open

Simply open `index.html` in a browser — no build step or server required (loads the SDK from the local `web/dist/` build).

```bash
open samples/web-sample/index.html
# or
npx serve samples/web-sample
```

> **Note:** If opening as `file://`, some browsers block `localStorage`/`clipboard` on file URLs. Use a local server (`npx serve`) for the full experience.

## What's Tested

| Feature | UI |
|---------|-----|
| `Deeplink.configure()` | On page load |
| `Deeplink.getInitData({ force: true })` | Button → shows matched data in log |
| `Deeplink.resetInitState()` | Button |
| `Deeplink.createLink()` | Button → shows URL + click to copy |
| `Deeplink.track()` | Three event buttons (button_tapped, purchase, signup) |

## Credentials

Edit the `<script>` block at the bottom of `index.html`:

```js
Deeplink.configure({
  apiKey: 'your-api-key',
  domain: 'https://your-backend.com',
});
```

## Using the CDN build instead

Replace the local script tag with the CDN version:

```html
<script src="https://unpkg.com/@deeplink/web/dist/deeplink.min.js"></script>
```
