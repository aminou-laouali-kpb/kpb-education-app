import { randomUUID } from 'node:crypto';

/**
 * L'identifiant de requête d'une action admin, tel que l'audit l'enregistre.
 *
 * Même règle que le helper privé de `GlobalExceptionFilter` : l'en-tête
 * `X-Request-Id` du client s'il est sûr à journaliser (borné, sans espace ni
 * caractère de contrôle), sinon un UUID neuf. Le filtre lit la requête Express ;
 * ici on reçoit la valeur brute de `req.headers['x-request-id']`, que Node type
 * `string | string[] | undefined`.
 *
 * Le contrôleur renvoie la valeur retenue dans `X-Request-Id` : l'équipe peut
 * alors relier une ligne d'audit à l'appel qui l'a écrite.
 */
const REQUEST_ID_PATTERN = /^[A-Za-z0-9._:-]{1,128}$/;

export function resolveRequestId(
  header: string | string[] | undefined,
): string {
  const raw = Array.isArray(header) ? header[0] : header;
  const candidate = raw?.trim();
  if (candidate && REQUEST_ID_PATTERN.test(candidate)) {
    return candidate;
  }
  return randomUUID();
}
