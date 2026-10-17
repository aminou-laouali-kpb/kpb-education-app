'use client';

import { useRouter, useSearchParams } from 'next/navigation';

import {
  type CommunityTab,
  communityHref,
  communityPermissions,
  resolveCommunityTab,
  visibleCommunityTabs,
} from '../../lib/community-admin';
import { useAdminAuth } from '../admin-auth-provider';
import { DashboardShell } from '../dashboard-shell';
import { useLocale } from '../locale-provider';
import { Alert, Button } from '../ui';
import { ContentPanel } from './content-panel';
import { DashboardPanel } from './dashboard-panel';
import { LegacyTaxonomy } from './legacy-taxonomy';
import { MembersPanel } from './members-panel';
import { ModerationLog } from './moderation-log';
import { ModerationQueue } from './moderation-queue';
import { SettingsPanel } from './settings-panel';

/**
 * Communauté — console de l'équipe : tableau de bord, file de modération,
 * contenus, membres, réglages du filtre, journal, et la taxonomie historique
 * du forum (gardée, dépréciée). L'onglet, la discussion et le membre ouverts
 * sont dans l'URL. Le conseiller (Counselor) ne voit que « Contenus » : lire
 * les discussions et y répondre.
 */
export function CommunityHub() {
  const { session } = useAdminAuth();
  const { t } = useLocale();
  const router = useRouter();
  const params = useSearchParams();
  const postId = params.get('post');
  const memberId = params.get('member');
  const permissions = communityPermissions(session?.user.role);
  const tabs = visibleCommunityTabs(permissions);
  const tab = resolveCommunityTab({ tab: params.get('tab'), post: postId, member: memberId }, tabs);

  const go = (target: Parameters<typeof communityHref>[0]) => router.push(communityHref(target));
  const openPost = (id: string | null) => go({ tab: 'content', post: id });
  const openMember = (id: string | null) => go({ tab: 'members', member: id });
  // Fiches membres : rôle R seulement (le conseiller n'y a pas accès).
  const openMemberIfAllowed = permissions.moderate ? (id: string) => openMember(id) : undefined;

  return (
    <DashboardShell title={t('communityAdmin.title')} subtitle={t('communityAdmin.subtitle')}>
      {session && !permissions.read ? (
        <Alert variant="warning">{t('communityAdmin.errors.forbidden')}</Alert>
      ) : (
        <div style={{ display: 'grid', gap: 14 }}>
          <nav style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }} aria-label={t('communityAdmin.tabsLabel')}>
            {tabs.map((key: CommunityTab) => (
              <Button
                key={key}
                size="sm"
                variant={tab === key ? 'primary' : 'secondary'}
                aria-current={tab === key ? 'page' : undefined}
                onClick={() => go({ tab: key })}
              >
                {t(`communityAdmin.tab.${key}`)}
              </Button>
            ))}
          </nav>
          {tab === 'dashboard' ? <DashboardPanel onOpenQueue={() => go({ tab: 'queue' })} /> : null}
          {tab === 'queue' ? (
            <ModerationQueue permissions={permissions} onOpenPost={(id) => openPost(id)} onOpenMember={(id) => openMember(id)} />
          ) : null}
          {tab === 'content' ? (
            <ContentPanel permissions={permissions} postId={postId} onOpenPost={openPost} onOpenMember={openMemberIfAllowed} />
          ) : null}
          {tab === 'members' ? (
            <MembersPanel permissions={permissions} memberId={memberId} onOpenMember={openMember} onOpenPost={(id) => openPost(id)} />
          ) : null}
          {tab === 'settings' ? <SettingsPanel permissions={permissions} /> : null}
          {tab === 'log' ? <ModerationLog onOpenPost={(id) => openPost(id)} /> : null}
          {tab === 'taxonomy' ? <LegacyTaxonomy /> : null}
        </div>
      )}
    </DashboardShell>
  );
}
