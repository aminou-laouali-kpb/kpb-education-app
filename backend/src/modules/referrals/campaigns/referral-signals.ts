import { createHmac } from 'node:crypto';
import { isIP } from 'node:net';

/**
 * Empreintes anti-fraude relevées au rattachement d'un filleul.
 *
 * Rien n'est stocké en clair : l'adresse IP, sa plage et les jetons d'appareil
 * passent par un HMAC-SHA256 à clé serveur (`KPB_REFERRAL_SIGNAL_SECRET`, à
 * défaut `KPB_JWT_SECRET`), tronqué à 32 caractères hexadécimaux. On peut dire
 * « ces deux rattachements viennent de la même adresse », pas « de quelle
 * adresse ». Changer la clé rend les anciennes empreintes incomparables aux
 * nouvelles — sans autre effet.
 *
 * L'app installée (2.3.0) n'envoie aucun identifiant d'appareil et AUCUNE
 * collecte nouvelle n'est ajoutée pour elle : on se sert du jeton push qu'elle
 * enregistre déjà (`DeviceToken`). La build 57 pourra envoyer un identifiant
 * d'installation dans l'en-tête `X-KPB-Device-Id` (préparé, non exigé).
 */

export function signalSecret(): string {
  return (
    process.env.KPB_REFERRAL_SIGNAL_SECRET ||
    process.env.KPB_JWT_SECRET ||
    'kpb-referral-signal-local-dev'
  );
}

export function signalHash(kind: string, value: string, secret = signalSecret()): string {
  return createHmac('sha256', secret).update(`${kind}:${value}`).digest('hex').slice(0, 32);
}

/** Retire le préfixe IPv4-mappé (« ::ffff:1.2.3.4 ») qu'Express laisse parfois. */
export function normalizeIp(raw: string | undefined | null): string | null {
  if (!raw) return null;
  let ip = raw.trim();
  if (ip.toLowerCase().startsWith('::ffff:') && isIP(ip.slice(7)) === 4) ip = ip.slice(7);
  return isIP(ip) ? ip : null;
}

/** /24 en IPv4, /48 en IPv6 : la « plage » d'une rafale. */
export function ipBlock(ip: string): string | null {
  const v = isIP(ip);
  if (v === 4) return ip.split('.').slice(0, 3).join('.') + '.0/24';
  if (v === 6) {
    const expanded = expandIpv6(ip);
    return expanded ? expanded.split(':').slice(0, 3).join(':') + '::/48' : null;
  }
  return null;
}

function expandIpv6(ip: string): string | null {
  const [head, tail] = ip.split('::');
  if (ip.split('::').length > 2) return null;
  const h = head ? head.split(':') : [];
  const t = tail !== undefined && tail !== '' ? tail.split(':') : [];
  if (tail === undefined && h.length !== 8) return null;
  const fill = 8 - h.length - t.length;
  if (fill < 0) return null;
  return [...h, ...Array(tail === undefined ? 0 : fill).fill('0'), ...t]
    .map((g) => g.toLowerCase().padStart(4, '0'))
    .join(':');
}

export interface AttributionSignalInput {
  ip: string | null | undefined;
  pushTokens: readonly string[];
  clientDeviceId: string | null | undefined;
}

export interface AttributionSignalHashes {
  ipHash: string | null;
  ipBlockHash: string | null;
  deviceHashes: string[];
  clientDeviceHash: string | null;
}

export function hashAttributionSignals(
  input: AttributionSignalInput,
  secret = signalSecret(),
): AttributionSignalHashes {
  const ip = normalizeIp(input.ip ?? null);
  const block = ip ? ipBlock(ip) : null;
  const device = (input.clientDeviceId ?? '').trim();
  return {
    ipHash: ip ? signalHash('ip', ip, secret) : null,
    ipBlockHash: block ? signalHash('ipblock', block, secret) : null,
    deviceHashes: [...new Set(input.pushTokens.filter(Boolean))]
      .map((t) => signalHash('push', t, secret))
      .sort(),
    clientDeviceHash:
      device.length >= 8 && device.length <= 128 ? signalHash('device', device, secret) : null,
  };
}
