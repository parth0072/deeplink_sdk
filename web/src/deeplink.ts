import { buildFingerprint } from './fingerprint';
import { DeeplinkConfig, DeeplinkData, CreateLinkInput, CreatedLink } from './types';

const STORAGE_KEY_INIT = 'dl_init_fetched';
const STORAGE_KEY_SESSION = 'dl_session_id';

function generateId(): string {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) return crypto.randomUUID();
  return Math.random().toString(36).slice(2) + Date.now().toString(36);
}

function sessionId(): string {
  try {
    const existing = localStorage.getItem(STORAGE_KEY_SESSION);
    if (existing) return existing;
    const id = generateId();
    localStorage.setItem(STORAGE_KEY_SESSION, id);
    return id;
  } catch {
    return generateId();
  }
}

async function request<T>(
  baseUrl: string,
  apiKey: string,
  path: string,
  options: RequestInit = {},
): Promise<T> {
  const res = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      ...(options.headers as Record<string, string> ?? {}),
    },
  });

  if (!res.ok) {
    let msg: string;
    try { msg = ((await res.json()) as { error?: string }).error ?? res.statusText; }
    catch { msg = res.statusText; }
    throw new Error(`Deeplink API [${res.status}]: ${msg}`);
  }

  const text = await res.text();
  return text ? JSON.parse(text) as T : undefined as T;
}

/**
 * Deeplink Web SDK
 *
 * **Via CDN:**
 * ```html
 * <script src="https://unpkg.com/@deeplink/web/dist/deeplink.min.js"></script>
 * <script>
 *   Deeplink.configure({ apiKey: 'your-key', domain: 'https://dl.yourapp.com' });
 * </script>
 * ```
 *
 * **Via npm:**
 * ```ts
 * import Deeplink from '@deeplink/web';
 * Deeplink.configure({ apiKey: 'your-key', domain: 'https://dl.yourapp.com' });
 * ```
 */
const Deeplink = {
  _apiKey: '',
  _baseUrl: '',
  _configured: false,

  // ── Setup ─────────────────────────────────────────────────────────────────

  /**
   * Configure the SDK. Call once before any other method.
   */
  configure(config: DeeplinkConfig): void {
    const base = config.domain.startsWith('http://') || config.domain.startsWith('https://')
      ? config.domain
      : `https://${config.domain}`;
    this._apiKey = config.apiKey;
    this._baseUrl = base.replace(/\/$/, '');
    this._configured = true;

    // Auto-capture UTM params from the current URL
    this._captureUtm();
  },

  // ── Deferred deep link ────────────────────────────────────────────────────

  /**
   * Fetch deferred deep link data. Typically called once on page load.
   *
   * Returns `DeeplinkData` if the page was opened via a tracked link,
   * or `null` if no match or already fetched.
   *
   * ```ts
   * const data = await Deeplink.getInitData();
   * if (data?.metadata?.product_id) {
   *   // Show personalised content
   * }
   * ```
   */
  async getInitData(opts: { force?: boolean } = {}): Promise<DeeplinkData | null> {
    this._require();

    try {
      const alreadyFetched = localStorage.getItem(STORAGE_KEY_INIT) === '1';
      if (alreadyFetched && !opts.force) return null;
    } catch { /* storage unavailable */ }

    const fingerprint = await buildFingerprint();
    const sid = sessionId();

    try {
      const data = await request<DeeplinkData>(
        this._baseUrl,
        this._apiKey,
        '/sdk/init',
        {
          method: 'POST',
          body: JSON.stringify({
            api_key: this._apiKey,
            fingerprint_hash: fingerprint,
            session_id: sid,
            platform: 'web',
            referrer: document.referrer || undefined,
            url: location.href,
          }),
        },
      );

      if (data) {
        try { localStorage.setItem(STORAGE_KEY_INIT, '1'); } catch { /* ignore */ }
        return data;
      }
    } catch { /* network errors are non-fatal */ }

    return null;
  },

  // ── Link creation ─────────────────────────────────────────────────────────

  /**
   * Create a deep link.
   *
   * ```ts
   * const link = await Deeplink.createLink({
   *   destinationUrl: 'https://yourapp.com/product/123',
   *   iosUrl: 'myapp://product/123',
   *   params: { product_id: '123' },
   * });
   * navigator.clipboard.writeText(link.url);
   * ```
   */
  async createLink(input: CreateLinkInput): Promise<CreatedLink> {
    this._require();
    return request<CreatedLink>(this._baseUrl, this._apiKey, '/sdk/link', {
      method: 'POST',
      body: JSON.stringify({
        api_key: this._apiKey,
        destination_url: input.destinationUrl,
        ios_url: input.iosUrl,
        android_url: input.androidUrl,
        alias: input.alias,
        title: input.title,
        description: input.description,
        metadata: input.params ?? {},
        utm_source: input.utmSource,
        utm_medium: input.utmMedium,
        utm_campaign: input.utmCampaign,
        expires_at: input.expiresAt,
      }),
    });
  },

  // ── Event tracking ────────────────────────────────────────────────────────

  /**
   * Track a custom event.
   *
   * ```ts
   * await Deeplink.track('page_view', { page: 'home' });
   * await Deeplink.track('cta_click', { button: 'download' });
   * ```
   */
  async track(event: string, properties: Record<string, unknown> = {}): Promise<void> {
    this._require();
    const sid = sessionId();
    try {
      await request<void>(this._baseUrl, this._apiKey, '/api/events', {
        method: 'POST',
        body: JSON.stringify({ api_key: this._apiKey, name: event, properties, session_id: sid }),
      });
    } catch { /* fire-and-forget */ }
  },

  // ── Helpers ───────────────────────────────────────────────────────────────

  /** Reset the "already fetched" guard (for testing). */
  resetInitState(): void {
    try { localStorage.removeItem(STORAGE_KEY_INIT); } catch { /* ignore */ }
  },

  _require(): void {
    if (!this._configured) throw new Error('Deeplink.configure() must be called first');
  },

  /** Capture UTM params from the current URL into sessionStorage for attribution. */
  _captureUtm(): void {
    try {
      const params = new URLSearchParams(location.search);
      const utm: Record<string, string> = {};
      ['utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content'].forEach((k) => {
        const v = params.get(k);
        if (v) utm[k] = v;
      });
      if (Object.keys(utm).length > 0) {
        sessionStorage.setItem('dl_utm', JSON.stringify(utm));
      }
    } catch { /* ignore */ }
  },
};

export default Deeplink;
export type { DeeplinkConfig, DeeplinkData, CreateLinkInput, CreatedLink } from './types';
