/**
 * Deeplink Node.js SDK — Express server example
 *
 * Shows a realistic server-side use case: create deep links on demand
 * via a REST endpoint (e.g. called from your marketing or referral flow).
 *
 * Run: npm run server
 */

import express from 'express';
import { DeeplinkClient } from '@deeplink/node';

const app = express();
app.use(express.json());

const client = new DeeplinkClient({
  apiKey: '7f9d682990f7b0d1502906357a35cd5f886293f8cf2377d3',
  baseUrl: 'https://deeplinkbe-production-5e4b.up.railway.app',
});

/**
 * POST /links
 * Body: { productId, utmSource?, utmCampaign? }
 * Returns: { url, alias }
 */
app.post('/links', async (req, res) => {
  const { productId, utmSource, utmCampaign } = req.body as {
    productId: string;
    utmSource?: string;
    utmCampaign?: string;
  };

  if (!productId) {
    res.status(400).json({ error: 'productId is required' });
    return;
  }

  try {
    const link = await client.createLink({
      destinationUrl: `https://yourapp.com/product/${productId}`,
      iosUrl: `myapp://product/${productId}`,
      androidUrl: `myapp://product/${productId}`,
      params: { product_id: productId },
      title: `Product ${productId}`,
      utmSource: utmSource ?? 'api',
      utmCampaign: utmCampaign ?? 'server-generated',
    });
    res.json({ url: link.url, alias: link.alias });
  } catch (err) {
    console.error('createLink error:', err);
    res.status(500).json({ error: 'Failed to create link' });
  }
});

/**
 * GET /links/:id/stats
 */
app.get('/links/:id/stats', async (req, res) => {
  try {
    const stats = await client.getAnalytics(req.params.id);
    res.json(stats);
  } catch (err) {
    console.error('getAnalytics error:', err);
    res.status(500).json({ error: 'Failed to fetch analytics' });
  }
});

/**
 * POST /events
 * Body: { event, properties? }
 */
app.post('/events', async (req, res) => {
  const { event, properties } = req.body as {
    event: string;
    properties?: Record<string, unknown>;
  };

  if (!event) {
    res.status(400).json({ error: 'event is required' });
    return;
  }

  try {
    await client.track(event, properties ?? {});
    res.json({ ok: true });
  } catch (err) {
    console.error('track error:', err);
    res.status(500).json({ error: 'Failed to track event' });
  }
});

const PORT = process.env.PORT ?? 3002;
app.listen(PORT, () => {
  console.log(`Deeplink sample server running on http://localhost:${PORT}`);
  console.log('');
  console.log('Try:');
  console.log(`  curl -X POST http://localhost:${PORT}/links \\`);
  console.log(`    -H "Content-Type: application/json" \\`);
  console.log(`    -d '{"productId":"abc123","utmCampaign":"launch"}'`);
});
