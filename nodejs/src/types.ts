export interface DeeplinkConfig {
  /** App API key from the Deeplink dashboard. */
  apiKey: string;
  /** Base URL of your Deeplink backend (e.g. "https://dl.yourapp.com"). */
  baseUrl: string;
}

export interface CreateLinkInput {
  /** Fallback destination URL. */
  destinationUrl: string;
  /** iOS deep link URL (e.g. "myapp://product/123"). */
  iosUrl?: string;
  /** Android deep link URL. */
  androidUrl?: string;
  /** Custom short alias. Auto-generated if omitted. */
  alias?: string;
  /** OG title for link previews. */
  title?: string;
  /** OG description. */
  description?: string;
  /** Arbitrary key-value metadata returned to the app via getInitData(). */
  params?: Record<string, string>;
  utmSource?: string;
  utmMedium?: string;
  utmCampaign?: string;
  /** ISO-8601 expiry timestamp. */
  expiresAt?: string;
}

export interface CreatedLink {
  id: string;
  url: string;
  alias: string;
}

export interface Link {
  id: string;
  alias: string;
  destination_url: string;
  ios_url: string | null;
  android_url: string | null;
  title: string | null;
  description: string | null;
  metadata: Record<string, string>;
  utm_source: string | null;
  utm_medium: string | null;
  utm_campaign: string | null;
  created_at: string;
}

export interface LinkStats {
  clicks: number;
  installs: number;
  unique_clicks: number;
  time_series: Array<{ date: string; clicks: number; installs: number }>;
}
