'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect } from 'react';

import { AdminCapability, hasAdminCapability } from '../lib/admin-capabilities';
import { canAccessCompetitionReadiness } from '../lib/competition-readiness-tabs';
import { useAdminAuth } from './admin-auth-provider';
import { useLocale } from './locale-provider';

// Minimal 24×24 stroke icons (currentColor) so the sidebar matches the
// handoff design without pulling an icon-font dependency.
const ICON_PATHS: Record<string, string> = {
  overview: 'M4 4h7v7H4zM13 4h7v4h-7zM13 11h7v9h-7zM4 14h7v6H4z',
  cases:
    'M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z',
  content: 'M6 3h9l4 4v14H6zM14 3v5h5M9 12h7M9 16h7',
  catalogue: 'M3 9l9-5 9 5-9 5zM6 11v6c0 1.5 2.7 3 6 3s6-1.5 6-3v-6',
  verification: 'M12 3l7 3v5c0 5-3.5 8.5-7 10-3.5-1.5-7-5-7-10V6zM9 12l2 2 4-4',
  scholarships: 'M12 4L2 9l10 5 10-5zM6 11.5V16c0 1.5 3 3 6 3s6-1.5 6-3v-4.5',
  serviceSales:
    'M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 7h18v12H3zM3 12h18',
  community:
    'M8 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM2 20c0-3 2.5-5 6-5s6 2 6 5M16 10a3 3 0 1 0-1.5-5.6M15 15.2c2.8.3 5 2.1 5 4.8',
  notifications:
    'M6 9a6 6 0 1 1 12 0c0 5 2 6 2 6H4s2-1 2-6M10 20a2 2 0 0 0 4 0',
  users: 'M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21c0-4 3.5-6 8-6s8 2 8 6',
  reports: 'M4 20V10M10 20V4M16 20v-7M21 20H3',
  // Un globe : l'espace « Études en France ».
  eef: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18M3 12h18M12 3c2.5 2.4 2.5 15.6 0 18M12 3c-2.5 2.4-2.5 15.6 0 18',
  readiness:
    'M4 20V7l8-4 8 4v13M8 11h8M8 15h5M16 15l1.5 1.5L20 14',
  // Un podium : la compétition ambassadeurs.
  referral: 'M3 20h18M5 20v-6h4v6M10 20V9h4v11M15 20v-8h4v8M12 3l1 2 2 .3-1.5 1.4.4 2.1L12 7.8 10.1 8.8l.4-2.1L9 5.3l2-.3z',
  logout: 'M15 4h4a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-4M10 8l-4 4 4 4M6 12h10',
};

function NavIcon({ name, size = 17 }: Readonly<{ name: string; size?: number }>) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.8}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      style={{ flexShrink: 0 }}
    >
      <path d={ICON_PATHS[name]} />
    </svg>
  );
}

interface NavLinkDefinition {
  href: string;
  labelKey: string;
  icon: string;
  visibleForRole?: (role: string) => boolean;
}

const NAV_LINKS: readonly NavLinkDefinition[] = [
  { href: '/', labelKey: 'nav.overview', icon: 'overview' },
  { href: '/cases', labelKey: 'nav.cases', icon: 'cases' },
  {
    href: '/competition-readiness',
    labelKey: 'nav.competitionReadiness',
    icon: 'readiness',
    visibleForRole: canAccessCompetitionReadiness,
  },
  { href: '/content', labelKey: 'nav.content', icon: 'content' },
  {
    href: '/catalogue',
    labelKey: 'nav.catalogue',
    icon: 'catalogue',
    // `AdminCatalogController` n'accepte qu'Admin, SuperAdmin et
    // ContentManager. Sans ce prédicat, un conseiller verrait l'entrée,
    // cliquerait, et récolterait un 403 — même motif que pour `/etudes-en-france`.
    visibleForRole: (role) =>
      hasAdminCapability(role, AdminCapability.ManageCatalogContent),
  },
  { href: '/verification', labelKey: 'nav.verification', icon: 'verification' },
  {
    href: '/scholarships',
    labelKey: 'nav.scholarshipsModeration',
    icon: 'scholarships',
  },
  {
    href: '/etudes-en-france',
    labelKey: 'nav.eef',
    icon: 'eef',
    // Masqué pour `moderator` et `content_manager`, que le contrôleur refuse.
    // Sans ce prédicat, ils voyaient l'entrée, cliquaient, et tombaient sur une
    // erreur 403 rendue dans une alerte : une invitation vers une porte fermée.
    // Aucune donnée n'était exposée — la garde backend tient — mais un menu qui
    // propose ce qu'il refuse apprend à ses utilisateurs à ignorer les erreurs.
    visibleForRole: (role) =>
      hasAdminCapability(role, AdminCapability.ViewInterestList),
  },
  {
    href: '/etudes-en-france/publication',
    labelKey: 'nav.eefPublication',
    icon: 'eef',
    // `EefPublicationController` n'accepte qu'Admin et SuperAdmin (pas
    // ContentManager : il édite le catalogue mais ne signe pas sa publication).
    visibleForRole: (role) =>
      hasAdminCapability(role, AdminCapability.PublishEefCatalog),
  },
  {
    href: '/parrainage',
    labelKey: 'nav.referralCampaigns',
    icon: 'referral',
    // `AdminReferralCampaignsController` : Admin, SuperAdmin, Commercial.
    visibleForRole: (role) =>
      hasAdminCapability(role, AdminCapability.ViewReferralCampaigns),
  },
  { href: '/service-sales', labelKey: 'nav.serviceSales', icon: 'serviceSales' },
  {
    href: '/community',
    labelKey: 'nav.community',
    icon: 'community',
    // Rôle R du contrat de la communauté (Moderator, ContentManager, Admin,
    // SuperAdmin) + Counselor, qui y lit les discussions pour y répondre.
    visibleForRole: (role) =>
      hasAdminCapability(role, AdminCapability.ReadCommunityDiscussions),
  },
  {
    href: '/notifications',
    labelKey: 'nav.notifications',
    icon: 'notifications',
  },
  { href: '/users', labelKey: 'nav.users', icon: 'users' },
  { href: '/reports', labelKey: 'nav.reports', icon: 'reports' },
];

function initialsOf(fullName: string): string {
  return fullName
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? '')
    .join('');
}

export function DashboardShell({
  title,
  subtitle,
  children,
}: Readonly<{
  title: string;
  /** Optional per-page contextual line under the title. Falls back to the
   *  generic shell.description when omitted. */
  subtitle?: string;
  children: React.ReactNode;
}>) {
  const pathname = usePathname();
  const router = useRouter();
  const { isReady, logout, session } = useAdminAuth();
  const { locale, setLocale, t } = useLocale();

  useEffect(() => {
    if (isReady && !session) {
      router.replace('/login');
    }
  }, [isReady, router, session]);

  if (!isReady || !session) {
    return (
      <div
        style={{
          minHeight: '100vh',
          display: 'grid',
          placeItems: 'center',
          background: 'var(--bg)',
          color: 'var(--text-muted)',
        }}
      >
        {t('shell.loading')}
      </div>
    );
  }

  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: 'minmax(220px, 250px) 1fr',
        minHeight: '100vh',
      }}
    >
      <aside
        className="kpb-sidebar"
        style={{
          background: 'var(--ink)',
          color: 'var(--text-on-ink)',
          padding: '18px 12px',
          display: 'flex',
          flexDirection: 'column',
          gap: 18,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '0 8px' }}>
          <div
            aria-hidden="true"
            style={{
              width: 34,
              height: 34,
              borderRadius: 10,
              background: 'var(--brand)',
              display: 'grid',
              placeItems: 'center',
              fontWeight: 800,
              fontSize: 15,
              color: 'var(--brand-fg)',
            }}
          >
            K
          </div>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <span style={{ fontSize: 14, fontWeight: 800, letterSpacing: '-0.2px' }}>
              {t('app.title')}
            </span>
            <span
              style={{
                fontSize: 9.5,
                fontWeight: 700,
                letterSpacing: '0.06em',
                textTransform: 'uppercase',
                color: 'var(--sky)',
              }}
            >
              {t('shell.eyebrow')}
            </span>
          </div>
        </div>

        <nav style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          {NAV_LINKS.filter(
            (link) =>
              !link.visibleForRole || link.visibleForRole(session.user.role),
          ).map((link) => {
            const isActive = pathname === link.href;
            return (
              <Link
                key={link.href}
                href={link.href}
                aria-current={isActive ? 'page' : undefined}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 11,
                  padding: '9px 10px',
                  borderRadius: 10,
                  background: isActive ? 'rgba(56,189,248,0.16)' : 'transparent',
                  color: isActive ? 'var(--text-on-ink)' : 'var(--text-faint)',
                  fontSize: 13,
                  fontWeight: isActive ? 800 : 600,
                }}
              >
                <span
                  style={{
                    color: isActive ? 'var(--sky)' : 'var(--text-muted)',
                    display: 'inline-flex',
                  }}
                >
                  <NavIcon name={link.icon} />
                </span>
                {t(link.labelKey)}
              </Link>
            );
          })}
        </nav>

        <div style={{ flex: 1 }} />

        <div
          role="group"
          aria-label={t('shell.language')}
          style={{ display: 'flex', gap: 6, padding: '0 2px' }}
        >
          {(['fr', 'en'] as const).map((code) => (
            <button
              key={code}
              type="button"
              onClick={() => setLocale(code)}
              aria-pressed={locale === code}
              style={{
                flex: 1,
                padding: '7px 10px',
                borderRadius: 10,
                border: 'none',
                background:
                  locale === code
                    ? 'rgba(56,189,248,0.16)'
                    : 'rgba(255,255,255,0.06)',
                color: locale === code ? 'var(--sky)' : 'var(--text-faint)',
                cursor: 'pointer',
                fontWeight: 800,
                fontSize: 11,
                letterSpacing: '0.04em',
              }}
            >
              {code.toUpperCase()}
            </button>
          ))}
        </div>

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            padding: 10,
            borderRadius: 10,
            background: 'rgba(255,255,255,0.06)',
          }}
        >
          <div
            aria-hidden="true"
            style={{
              width: 32,
              height: 32,
              borderRadius: '50%',
              background: 'var(--sky)',
              color: 'var(--ink)',
              display: 'grid',
              placeItems: 'center',
              fontSize: 11,
              fontWeight: 800,
              flexShrink: 0,
            }}
          >
            {initialsOf(session.user.fullName)}
          </div>
          <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
            <span
              style={{
                fontSize: 12,
                fontWeight: 800,
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {session.user.fullName}
            </span>
            <span
              title={session.user.email}
              style={{
                fontSize: 10,
                color: 'var(--text-faint)',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {session.user.role} · {session.user.email}
            </span>
          </div>
          <button
            type="button"
            aria-label={t('shell.logout')}
            title={t('shell.logout')}
            onClick={() => {
              void logout();
              router.replace('/login');
            }}
            style={{
              border: 'none',
              background: 'transparent',
              color: 'var(--text-faint)',
              cursor: 'pointer',
              padding: 4,
              display: 'inline-flex',
              borderRadius: 8,
            }}
          >
            <NavIcon name="logout" size={16} />
          </button>
        </div>
      </aside>

      <main style={{ padding: '24px 28px', background: 'var(--bg)', minWidth: 0 }}>
        <h2
          style={{
            marginTop: 0,
            marginBottom: 4,
            fontSize: 'var(--text-xl)',
            fontWeight: 800,
            color: 'var(--ink)',
          }}
        >
          {title}
        </h2>
        <p style={{ marginTop: 0, color: 'var(--text-muted)', fontSize: 'var(--text-sm)' }}>
          {subtitle ?? t('shell.description')}
        </p>
        {children}
      </main>
    </div>
  );
}
