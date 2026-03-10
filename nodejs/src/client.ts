import { DeeplinkConfig, CreateLinkInput, CreatedLink, Link, LinkStats } from './types';

export class DeeplinkClient {
  private readonly apiKey: string;
  private readonly baseUrl: string;

  constructor({ apiKey, baseUrl }: DeeplinkConfig) {
    this.apiKey = apiKey;
    this.baseUrl = baseUrl.replace(/\/$/, '');
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  private async request<T>(path: string, init: RequestInit = {}): Promise<T> {
    const res = await fetch(`${this.baseUrl}${path}`, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': this.apiKey,
        ...(init.headers as Record<string, string> ?? {}),
      },
    });

    if (!res.ok) {
      let msg: string;
      try { msg = (await res.json() as { error?: string }).error ?? res.statusText; }
      catch { msg = res.statusText; }
      throw new Error(`Deeplink API [${res.status}]: ${msg}`);
    }

    const text = await res.text();
    return text ? JSON.parse(text) as T : undefined as T;
  }

  // ── Link management ───────────────────────────────────────────────────────

  /**
   * Create a deep link.
   *
   * ```ts
   * const link = await client.createLink({
   *   destinationUrl: 'https://yourapp.com/product/123',
   *   iosUrl: 'myapp://product/123',
   *   androidUrl: 'myapp://product/123',
   *   params: { product_id: '123' },
   *   utmCampaign: 'launch',
   * });
   * console.log(link.url); // https://dl.yourapp.com/abc123
   * ```
   */
  async createLink(input: CreateLinkInput): Promise<CreatedLink> {
    return this.request<CreatedLink>('/sdk/link', {
      method: 'POST',
      body: JSON.stringify({
        api_key: this.apiKey,
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
  }

  /**
   * Get a link by ID.
   */
  async getLink(id: string): Promise<Link> {
    return this.request<Link>(`/api/links/${id}`);
  }

  /**
   * List all links for this app.
   */
  async listLinks(): Promise<Link[]> {
    return this.request<Link[]>('/api/links');
  }

  /**
   * Delete a link by ID.
   */
  async deleteLink(id: string): Promise<void> {
    return this.request<void>(`/api/links/${id}`, { method: 'DELETE' });
  }

  // ── Analytics ─────────────────────────────────────────────────────────────

  /**
   * Get click/install stats for a specific link.
   *
   * ```ts
   * const stats = await client.getAnalytics('link-id', { from: '2024-01-01', to: '2024-01-31' });
   * ```
   */
  async getAnalytics(linkId: string, params?: { from?: string; to?: string }): Promise<LinkStats> {
    const qs = new URLSearchParams();
    if (params?.from) qs.set('from', params.from);
    if (params?.to) qs.set('to', params.to);
    const query = qs.size ? `?${qs}` : '';
    return this.request<LinkStats>(`/api/analytics/${linkId}${query}`);
  }

  // ── Event tracking ────────────────────────────────────────────────────────

  /**
   * Track a server-side event.
   *
   * ```ts
   * await client.track('purchase', { amount: 49.99, currency: 'USD' });
   * ```
   */
  async track(
    event: string,
    properties: Record<string, unknown> = {},
    sessionId?: string,
  ): Promise<void> {
    return this.request<void>('/api/events', {
      method: 'POST',
      body: JSON.stringify({
        api_key: this.apiKey,
        name: event,
        properties,
        session_id: sessionId,
      }),
    });
  }
}
