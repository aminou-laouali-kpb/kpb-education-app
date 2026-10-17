'use client';

export interface AdminSessionUser {
  id: string;
  fullName: string;
  email: string;
  role: string;
  languageScope: string[];
}

export interface AdminSession {
  user: AdminSessionUser;
}

export interface ApiOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  body?: unknown;
  headers?: Readonly<Record<string, string>>;
  signal?: AbortSignal;
}

const API_BASE_URL =
  process.env.NEXT_PUBLIC_KPB_API_BASE_URL ?? 'http://127.0.0.1:4000/api';

// Session tokens now live in httpOnly cookies set by the backend. This key is
// only kept to purge any token left in localStorage by older builds.
const LEGACY_STORAGE_KEY = 'kpb-admin-session';

export function clearLegacySession() {
  if (typeof window !== 'undefined') {
    window.localStorage.removeItem(LEGACY_STORAGE_KEY);
  }
}

export async function loginAdmin(
  email: string,
  password?: string,
): Promise<AdminSession> {
  return apiFetch<AdminSession>('/auth/admin/login', {
    method: 'POST',
    body: { email, password },
  });
}

export async function fetchSession(): Promise<AdminSessionUser> {
  const response = await apiFetch<{ user: AdminSessionUser }>(
    '/auth/admin/session',
  );
  return response.user;
}

export async function logoutAdmin(): Promise<void> {
  try {
    await apiFetch('/auth/admin/logout', { method: 'POST' });
  } catch {
    // Best-effort: clearing the local UI state matters more than the network call.
  }
}

/**
 * Comme [apiFetch], mais rend le corps BRUT.
 *
 * `apiFetch` termine par un `JSON.parse`, ce qui est exactement ce qu'il faut
 * pour toutes les routes sauf une : l'export CSV de la liste d'intérêt. Le faire
 * passer par le chemin JSON échouerait sur la première virgule.
 *
 * Pourquoi pas un simple `<a href>` vers l'endpoint : la session admin vit dans
 * un cookie httpOnly, et un téléchargement déclenché par le navigateur
 * l'emporterait — mais on perdrait la gestion d'erreur. Un 401 rendrait un
 * fichier nommé `export.csv` contenant « Unauthorized », que quelqu'un ouvrirait
 * dans Excel en croyant que la liste est vide. Ici l'échec est une exception que
 * la page affiche.
 */
export type ApiError = Error & { status?: number; body?: string };

/**
 * Extrait le message lisible d'une réponse d'erreur Nest
 * (`{"message":"…","statusCode":409}`, ou un tableau de messages de
 * validation). Avant, le JSON brut — accolades comprises — s'affichait tel
 * quel dans les alertes des pages. Le corps brut reste dans `body`.
 */
export function readableErrorText(text: string, status: number): string {
  if (!text) return `Request failed with status ${status}`;
  try {
    const parsed: unknown = JSON.parse(text);
    if (parsed && typeof parsed === 'object' && 'message' in parsed) {
      const { message } = parsed as { message: unknown };
      if (Array.isArray(message) && message.length > 0) {
        return message.map(String).join(' ');
      }
      if (typeof message === 'string' && message !== '') return message;
    }
  } catch {
    // Pas du JSON : le texte brut est déjà le message.
  }
  return text;
}

/** Routes où un 401 est une réponse normale, pas une session expirée. */
const AUTH_PATHS = ['/auth/admin/login', '/auth/admin/session', '/auth/admin/logout'];

async function toApiError(response: Response, path: string): Promise<ApiError> {
  const text = await response.text().catch(() => '');
  const error = new Error(readableErrorText(text, response.status)) as ApiError;
  error.status = response.status;
  error.body = text;
  if (
    response.status === 401 &&
    typeof window !== 'undefined' &&
    !AUTH_PATHS.some((p) => path.startsWith(p)) &&
    window.location.pathname !== '/login'
  ) {
    // Session expirée en cours d'usage : retour à la connexion au lieu d'une
    // alerte « Unauthorized » que rien ne permet de corriger depuis la page.
    window.location.assign('/login?expired=1');
  }
  return error;
}

export async function apiFetchText(
  path: string,
  options: ApiOptions = {},
): Promise<string> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: options.method ?? 'GET',
    cache: 'no-store',
    credentials: 'include',
    headers: { ...options.headers },
    signal: options.signal,
  });

  if (!response.ok) {
    throw await toApiError(response, path);
  }

  return response.text();
}

export async function apiFetch<T>(
  path: string,
  options: ApiOptions = {},
): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: options.method ?? 'GET',
    cache: 'no-store',
    // Send/receive the httpOnly session cookie on every request.
    credentials: 'include',
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
    signal: options.signal,
    body:
      options.body === undefined ? undefined : JSON.stringify(options.body),
  });

  if (!response.ok) {
    throw await toApiError(response, path);
  }

  // Mutations frequently return 204 No Content or an empty body; calling
  // response.json() on those throws and surfaces as a false failure even
  // though the write succeeded.
  if (response.status === 204) {
    return undefined as T;
  }
  const text = await response.text();
  if (!text) {
    return undefined as T;
  }
  return JSON.parse(text) as T;
}
