/**
 * Deeplink Node.js SDK — interactive demo
 *
 * Run: npm run demo
 */

import { DeeplinkClient } from '@deeplink/node';

const client = new DeeplinkClient({
  apiKey: '7f9d682990f7b0d1502906357a35cd5f886293f8cf2377d3',
  baseUrl: 'https://deeplinkbe-production-5e4b.up.railway.app',
});

const sep = (label: string) => console.log(`\n── ${label} ──`);
const log = (msg: string) => console.log('  ' + msg);

async function run() {
  console.log('Deeplink Node.js SDK Demo\n');

  // ── 1. Create a link ───────────────────────────────────────────────────────
  sep('Create Link');
  try {
    const link = await client.createLink({
      destinationUrl: 'https://yourapp.com/product/123',
      iosUrl: 'myapp://product/123',
      androidUrl: 'myapp://product/123',
      params: { product_id: '123', source: 'nodejs-sample' },
      title: 'Sample Product',
      utmSource: 'sample',
      utmMedium: 'nodejs',
      utmCampaign: 'sdk-test',
    });
    log(`✅ url:   ${link.url}`);
    log(`   alias: ${link.alias}`);
  } catch (err) {
    log(`❌ ${err}`);
    log('   (Is the backend running and API key correct?)');
  }

  // ── 2. Event tracking ──────────────────────────────────────────────────────
  sep('Event Tracking');
  try {
    await client.track('button_tapped', { screen: 'home', button: 'cta' });
    log('✅ Tracked: button_tapped');

    await client.track('purchase', { amount: 49.99, currency: 'USD' });
    log('✅ Tracked: purchase');

    await client.track('signup', { method: 'email' });
    log('✅ Tracked: signup');
  } catch (err) {
    log(`❌ ${err}`);
  }

  console.log('\nDemo complete.');
  console.log('View results in your admin → Links + Funnels pages.');
}

run().catch(console.error);
