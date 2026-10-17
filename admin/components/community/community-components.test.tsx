import { ReactElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';

import { InternalRole } from '../../lib/admin-capabilities';
import {
  type AdminPost,
  type AdminReply,
  type CommunityStats,
  communityPermissions,
  type FiltersConfig,
  type QueueItem,
} from '../../lib/community-admin';
import { LocaleProvider } from '../locale-provider';
import { ContentActionDialog, SanctionDialog } from './action-dialogs';
import { PostDetailView } from './content-panel';
import { StatsView } from './dashboard-panel';
import { MemberDetailView, MostReportedTable } from './members-panel';
import { QueueList, QueuePreview } from './moderation-queue';
import { FiltersView, FixedSettings } from './settings-panel';
import { LoadError, SoonState } from './shared';

// Rendu serveur (react-dom/server, environnement node) : les effets ne
// tournent pas, on lit le balisage du premier rendu (même méthode que
// `components/scholarships/*.test.tsx`). Les règles (motif, durée, tri,
// raccourcis, erreurs) sont testées dans `lib/community-admin.test.ts`.

function render(element: ReactElement): string {
  return renderToStaticMarkup(<LocaleProvider>{element}</LocaleProvider>);
}

const noop = () => {};
const asyncNoop = async () => {};
const moderator = communityPermissions(InternalRole.Moderator);
const contentManager = communityPermissions(InternalRole.ContentManager);
const admin = communityPermissions(InternalRole.Admin);

const author = {
  kind: 'member',
  memberId: 'cm_42',
  displayName: 'Aïcha K.',
  countryName: 'Niger',
  badges: ['verified_alumni'],
  userId: 'usr_1',
  fullName: 'Aïcha Kader',
  email: 'aicha.kader@example.org',
  isMinor: true,
  accountCreatedAt: '2026-01-01T00:00:00.000Z',
  adminId: null,
};

const scamPost: AdminPost = {
  id: 'cp_1',
  type: 'question',
  title: 'Agent pour la bourse Eiffel ?',
  body: '…',
  segments: [
    { kind: 'text', text: 'Écris-moi pour ' },
    { kind: 'mention', type: 'scholarship', id: 'clx1', label: 'Bourse Eiffel' },
    { kind: 'text', text: ' ' },
    { kind: 'hashtag', tag: 'campusfrance', display: 'CampusFrance' },
    { kind: 'text', text: ' ' },
    { kind: 'link', url: 'https://www.campusfrance.org/fr', text: 'https://www.campusfrance.org/fr' },
    { kind: 'segment_futur', text: ' (suite)' },
  ],
  mentions: [{ type: 'scholarship', id: 'clx1', label: 'Bourse Eiffel', countryId: 'fra' }],
  author,
  createdAt: '2026-10-16T08:00:00.000Z',
  status: 'pending_review',
  statusReason: 'auto_filter',
  filterFlags: ['whatsapp', 'money_request', 'nouveau_drapeau'],
  openReportCount: 2,
};

const queueItem: QueueItem = {
  key: 'post:cp_1',
  targetType: 'post',
  post: scamPost,
  reply: null,
  member: null,
  parentPost: null,
  reports: [
    {
      id: 'crp_1',
      targetType: 'post',
      targetId: 'cp_1',
      reason: 'scam',
      status: 'open',
      createdAt: '2026-10-16T09:00:00.000Z',
      details: 'Demande des frais',
      reporter: { memberId: 'cm_7', displayName: 'Moussa D.' },
    },
  ],
  openReportCount: 2,
  flaggedAt: '2026-10-16T08:00:00.000Z',
  waitingHours: 30,
};

describe('file de modération (rendu)', () => {
  it('liste : type, statut, signalements, attente, délai dépassé, motif du filtre', () => {
    const html = render(<QueueList items={[queueItem]} selectedKey="post:cp_1" onSelect={noop} />);
    expect(html).toContain('Agent pour la bourse Eiffel ?');
    expect(html).toContain('En attente de revue');
    expect(html).toContain('2 signalement(s)');
    expect(html).toContain('⚠ attend depuis 30 h');
    expect(html).toContain('Filtre anti-arnaque · WhatsApp / Telegram, Demande d&#x27;argent, nouveau drapeau');
    expect(html).toMatch(/aria-pressed="true"[^>]*>|data-queue-key="post:cp_1" aria-pressed="true"/);
  });

  it('liste vide : état vide, pas d’erreur', () => {
    const html = render(<QueueList items={[]} selectedKey={null} onSelect={noop} />);
    expect(html).toContain('File vide');
    expect(html).not.toContain('role="alert"');
  });

  it('aperçu : segments, mention, lien non cliquable, signalements, actions avec raccourci', () => {
    const html = render(
      <QueuePreview
        item={queueItem}
        permissions={moderator}
        history={null}
        historyLoading={false}
        onContentAction={noop}
        onSanction={noop}
        onOpenPost={noop}
        onOpenMember={noop}
      />,
    );
    expect(html).toContain('data-segment="mention"');
    expect(html).toContain('@Bourse Eiffel');
    expect(html).toContain('#CampusFrance');
    expect(html).toContain('<code data-segment="link">https://www.campusfrance.org/fr</code>');
    expect(html).not.toMatch(/<a [^>]*href="https:\/\/www\.campusfrance/);
    expect(html).toContain(' (suite)');
    expect(html).toContain('Arnaque');
    expect(html).toContain('« Demande des frais »');
    expect(html).toContain('Mineur');
    for (const cta of ['Rétablir', 'Masquer', 'Supprimer', 'Classer sans suite', 'Avertir', 'Lecture seule', 'Bannir']) {
      expect(html).toContain(cta);
    }
    expect(html).toContain('aria-keyshortcuts="r"');
    expect(html).toContain('aria-keyshortcuts="b"');
  });

  it('modérateur : jamais l’e-mail ni le nom complet de l’élève', () => {
    const html = render(
      <QueuePreview
        item={queueItem}
        permissions={moderator}
        history={null}
        historyLoading={false}
        onContentAction={noop}
        onSanction={noop}
        onOpenPost={noop}
        onOpenMember={noop}
      />,
    );
    expect(html).not.toContain('aicha.kader@example.org');
    expect(html).not.toContain('Aïcha Kader');
    expect(html).not.toContain('data-identity="real"');
  });

  it('administrateur : identité réelle affichée', () => {
    const html = render(
      <QueuePreview
        item={queueItem}
        permissions={admin}
        history={null}
        historyLoading={false}
        onContentAction={noop}
        onSanction={noop}
        onOpenPost={noop}
        onOpenMember={noop}
      />,
    );
    expect(html).toContain('aicha.kader@example.org');
  });

  it('gestionnaire de contenu : actions sur le contenu, aucune sanction', () => {
    const html = render(
      <QueuePreview
        item={queueItem}
        permissions={contentManager}
        history={null}
        historyLoading={false}
        onContentAction={noop}
        onSanction={noop}
        onOpenPost={noop}
        onOpenMember={noop}
      />,
    );
    expect(html).toContain('Masquer');
    expect(html).not.toContain('Bannir');
    expect(html).not.toContain('Avertir');
  });

  it('historique de l’auteur : restriction et sanctions passées', () => {
    const html = render(
      <QueuePreview
        item={queueItem}
        permissions={moderator}
        history={{
          ...author,
          stats: { postsCount: 3, repliesCount: 5, helpfulAnswersCount: 1 },
          openReportCount: 4,
          restriction: { kind: 'read_only', until: '2026-10-20T00:00:00.000Z', reason: 'Spam' },
          sanctions: [
            {
              id: 's1',
              kind: 'warning',
              reason: 'Lien douteux',
              endsAt: null,
              createdAt: '2026-10-01T00:00:00.000Z',
              revokedAt: null,
              active: false,
            },
          ],
        }}
        historyLoading={false}
        onContentAction={noop}
        onSanction={noop}
        onOpenPost={noop}
        onOpenMember={noop}
      />,
    );
    expect(html).toContain('Historique de l&#x27;auteur');
    expect(html).toContain('3 publication(s), 5 réponse(s) visibles · 4 signalement(s) ouvert(s) · 1 sanction(s)');
    expect(html).toContain('Lien douteux');
    expect(html).toContain('Lecture seule');
  });
});

describe('confirmations avec motif obligatoire (rendu)', () => {
  it('masquer : dialogue modal, motif requis, bouton désactivé tant que le motif est vide', () => {
    const html = render(
      <ContentActionDialog action="hide" targetLabel="la publication" onConfirm={asyncNoop} onCancel={noop} />,
    );
    expect(html).toContain('aria-modal="true"');
    expect(html).toContain('Masquer la publication ?');
    expect(html).toMatch(/<textarea[^>]*required=""/);
    expect(html).toContain('aria-required="true"');
    expect(html).toMatch(/<button[^>]*disabled=""[^>]*>Masquer<\/button>/);
    expect(html).toContain('Prévenir l&#x27;auteur');
  });

  it('classer les signalements : pas de case « prévenir l’auteur » (sans effet au contrat)', () => {
    const html = render(
      <ContentActionDialog action="dismiss_reports" targetLabel="la réponse" onConfirm={asyncNoop} onCancel={noop} />,
    );
    expect(html).toContain('Classer les signalements de la réponse ?');
    expect(html).not.toContain('Prévenir l&#x27;auteur');
  });

  it('fermé : rien', () => {
    expect(render(<ContentActionDialog action={null} targetLabel="x" onConfirm={asyncNoop} onCancel={noop} />)).toBe('');
    expect(render(<SanctionDialog kind={null} memberName="x" onConfirm={asyncNoop} onCancel={noop} />)).toBe('');
  });

  it('sanction : choix du type, motif requis, confirmation désactivée au départ', () => {
    const html = render(<SanctionDialog kind="warning" memberName="Aïcha K." onConfirm={asyncNoop} onCancel={noop} />);
    expect(html).toContain('Avertir Aïcha K. ?');
    expect(html).toContain('<option value="read_only">Lecture seule</option>');
    expect(html).toMatch(/<button[^>]*disabled=""[^>]*>Avertir<\/button>/);
  });
});

describe('états d’erreur (rendu)', () => {
  it('route absente : « Bientôt », sans alerte rouge', () => {
    const error = Object.assign(new Error('Cannot GET /api/admin/community/stats'), {
      status: 404,
      body: JSON.stringify({ message: 'Cannot GET /api/admin/community/stats?days=30', statusCode: 404 }),
    });
    const html = render(<LoadError error={error} />);
    expect(html).toContain('data-state="soon"');
    expect(html).toContain('Bientôt');
    expect(html).not.toContain('role="alert"');
  });

  it('panne serveur : alerte lisible', () => {
    const error = Object.assign(new Error('Request failed with status 500'), { status: 500, body: '' });
    const html = render(<LoadError error={error} />);
    expect(html).toContain('role="alert"');
    expect(html).toContain('Le serveur n&#x27;a pas répondu. Réessayez.');
  });

  it('rôle refusé : message dédié', () => {
    const error = Object.assign(new Error('Forbidden resource'), {
      status: 403,
      body: JSON.stringify({ statusCode: 403, message: 'Forbidden resource' }),
    });
    expect(render(<LoadError error={error} />)).toContain('Votre rôle ne permet pas cette action.');
  });

  it('état « bientôt » personnalisé', () => {
    expect(render(<SoonState title="Liste des sanctions" />)).toContain('Liste des sanctions');
  });
});

const visibleReply: AdminReply = {
  id: 'cr_1',
  postId: 'cp_2',
  body: 'Le dossier prend 3 semaines.',
  author: { kind: 'kpb_team', memberId: null, displayName: 'Équipe KPB', countryName: null, badges: ['kpb_team'] },
  createdAt: '2026-10-17T10:00:00.000Z',
  status: 'visible',
  statusReason: null,
  isVerified: false,
};

describe('discussion (rendu)', () => {
  const detail = {
    post: { ...scamPost, id: 'cp_2', status: 'visible', statusReason: null, filterFlags: [], isPinned: true, openReportCount: 0 },
    replies: [visibleReply, { ...visibleReply, id: 'cr_2', isVerified: true, body: 'Vérifiée' }],
    reports: [],
    log: [
      {
        id: 'l1',
        action: 'pin',
        targetType: 'post',
        targetId: 'cp_2',
        reason: null,
        moderatorName: 'Fatima',
        moderatorRole: 'moderator',
        createdAt: '2026-10-17T10:00:00.000Z',
        postId: 'cp_2',
      },
    ],
  };

  it('épinglée, réponse vérifiée, badge Équipe KPB, actions de l’équipe', () => {
    const html = render(
      <PostDetailView
        detail={detail}
        permissions={contentManager}
        busy={null}
        onOpenMember={noop}
        onAction={noop}
        onPin={noop}
        onVerify={noop}
      />,
    );
    expect(html).toContain('Désépingler');
    expect(html).toContain('Équipe KPB');
    expect(html).toContain('Réponse vérifiée par KPB');
    expect(html).toContain('Marquer « Réponse vérifiée par KPB »');
    expect(html).toContain('Retirer la vérification');
    expect(html).toContain('Réponses (2)');
    expect(html).toContain('Fatima');
  });
});

describe('membres (rendu)', () => {
  it('les plus signalés d’abord', () => {
    const member = (id: string, name: string) => ({ kind: 'member', memberId: id, displayName: name, countryName: 'Bénin', badges: [] });
    const html = render(
      <MostReportedTable
        data={{
          counts: { autoHidden: 0, reported: 0, members: 2 },
          nextCursor: null,
          items: [
            { ...queueItem, key: 'member:a', targetType: 'member', post: null, member: member('a', 'Peu Signalé'), openReportCount: 1 },
            { ...queueItem, key: 'member:b', targetType: 'member', post: null, member: member('b', 'Très Signalé'), openReportCount: 5 },
          ],
        }}
        onOpenMember={noop}
      />,
    );
    expect(html.indexOf('Très Signalé')).toBeLessThan(html.indexOf('Peu Signalé'));
  });

  it('fiche : levée proposée pour une sanction active (rôle S), pas pour le gestionnaire de contenu', () => {
    const member = {
      ...author,
      sanctions: [
        {
          id: 's1',
          kind: 'read_only',
          reason: 'Spam',
          endsAt: '2026-10-24T00:00:00.000Z',
          createdAt: '2026-10-17T00:00:00.000Z',
          revokedAt: null,
          active: true,
        },
      ],
    };
    const props = { member, onSanction: noop, onRevoke: noop, onOpenPost: noop };
    expect(render(<MemberDetailView {...props} permissions={moderator} />)).toContain('>Lever<');
    const cm = render(<MemberDetailView {...props} permissions={contentManager} />);
    expect(cm).not.toContain('>Lever<');
    expect(cm).not.toContain('Bannir');
  });
});

describe('réglages (rendu)', () => {
  const config: FiltersConfig = {
    allowedDomains: {
      builtin: ['campusfrance.org', '*.gouv.fr'],
      catalogHostsCount: 412,
      custom: [{ id: 'f1', kind: 'allowed_domain', value: 'univ-lyon1.fr', createdAt: '2026-10-17T00:00:00.000Z', createdBy: 'Admin' }],
    },
    blockedTerms: { builtinCount: 80, custom: [] },
  };

  it('administrateur : ajout et retrait possibles', () => {
    const html = render(<FiltersView config={config} canEdit onAdd={asyncNoop} onRemove={noop} />);
    expect(html).toContain('univ-lyon1.fr');
    expect(html).toContain('412 sites officiels');
    expect(html).toContain('Ajouter un domaine');
    expect(html).toContain('aria-label="Retirer univ-lyon1.fr"');
  });

  it('modérateur : lecture seule', () => {
    const html = render(<FiltersView config={config} canEdit={false} onAdd={asyncNoop} onRemove={noop} />);
    expect(html).not.toContain('Ajouter un domaine');
    expect(html).toContain('Modification réservée aux administrateurs.');
  });

  it('seuils et charte : affichés, marqués « Bientôt »', () => {
    const html = render(<FixedSettings />);
    expect(html).toContain('2026-10-v1');
    expect(html).toContain('Bientôt');
  });
});

describe('tableau de bord (rendu)', () => {
  const stats: CommunityStats = {
    window: { from: '2026-09-17T00:00:00.000Z', to: '2026-10-17T00:00:00.000Z', days: 30 },
    posts: { total: 120, byType: { question: 80, experience: 25, advice: 15 }, byStatus: { visible: 110, pending_review: 4 } },
    replies: { total: 410, byTeam: 38 },
    helpfulReactions: 530,
    reports: { opened: 14, open: 3, resolved: 11, medianResolutionHours: 6.5 },
    autoHidden: 9,
    unansweredQuestions: 12,
    verifiedAnswers: 21,
    activeMembers: 85,
    newMembers: 40,
    activeSanctions: 2,
    daily: [{ date: '2026-10-17', posts: 5, replies: 17 }],
  };

  it('volumes, file, délai médian, questions sans réponse, activité quotidienne', () => {
    const html = render(<StatsView stats={stats} onOpenQueue={noop} />);
    expect(html).toContain('Signalements ouverts');
    expect(html).toContain('6,5 h');
    expect(html).toContain('Questions sans réponse');
    expect(html).toContain('dont 38 de l&#x27;équipe');
    expect(html).toContain('4 publication(s) en attente de revue');
    expect(html).toContain('2026-10-17');
  });
});
