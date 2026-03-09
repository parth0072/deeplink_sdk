export interface DeeplinkConfig {
  /** App API key from the Deeplink dashboard. */
  apiKey: string;
  /** Base URL of your Deeplink backend (e.g. "https://dl.yourapp.com"). */
  domain: string;
}

export interface DeeplinkData {
  destinationUrl?: string;
  iosUrl?: string;
  androidUrl?: string;
  alias?: string;
  metadata: Record<string, unknown>;
}

export interface CreateLinkInput {
  destinationUrl: string;
  iosUrl?: string;
  androidUrl?: string;
  alias?: string;
  title?: string;
  description?: string;
  params?: Record<string, string>;
  utmSource?: string;
  utmMedium?: string;
  utmCampaign?: string;
  expiresAt?: string;
}

export interface CreatedLink {
  id: string;
  url: string;
  alias: string;
}
