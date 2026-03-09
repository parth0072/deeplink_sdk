/**
 * Builds a lightweight browser fingerprint for deferred deep link matching.
 * Not a tracking fingerprint — used only to correlate a web click with an
 * app install within a short time window.
 */
export async function buildFingerprint(): Promise<string> {
  const parts: string[] = [
    navigator.userAgent,
    navigator.language,
    String(screen.width),
    String(screen.height),
    String(screen.colorDepth),
    Intl.DateTimeFormat().resolvedOptions().timeZone,
    String(navigator.hardwareConcurrency ?? ''),
    String((navigator as Navigator & { deviceMemory?: number }).deviceMemory ?? ''),
  ];

  const raw = parts.join('|');

  if (typeof crypto !== 'undefined' && crypto.subtle) {
    const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(raw));
    return Array.from(new Uint8Array(buf))
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');
  }

  // Fallback: djb2 hash
  let hash = 5381;
  for (let i = 0; i < raw.length; i++) {
    hash = ((hash << 5) + hash) ^ raw.charCodeAt(i);
    hash >>>= 0; // keep unsigned 32-bit
  }
  return hash.toString(16);
}
