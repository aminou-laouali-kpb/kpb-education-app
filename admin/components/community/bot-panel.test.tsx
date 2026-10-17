import { ReactElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';

import type { AdminPost, BotDraft, BotDraftDetail, BotStats } from '../../lib/community-admin';
import { LocaleProvider } from '../locale-provider';
import { BotDraftDetailView, BotDraftList, BotStatsView } from './bot-panel';

// Rendu serveur (effets non exécutés), même méthode que community-components.test.tsx.
function render(element: ReactElement): string {
  return renderToStaticMarkup(<LocaleProvider>{element}</LocaleProvider>);
}

const noop = () => {};

const post: AdminPost = {
  id: 'cp_1',
  type: 'question',
  title: 'La bourse Eiffel est-elle ouverte ?',
  body: '…',
  segments: [
    { kind: 'text', text: 'Est-ce que ' },
    { kind: 'mention', type: 'scholarship', id: 'clx1', label: 'Bourse Eiffel' },
    { kind: 'text', text: ' est ouverte ?' },
  ],
  author: {
    kind: 'member',
    memberId: 'cm_1',
    displayName: 'Aïcha K.',
    countryName: 'Niger',
    badges: [],
    fullName: 'Aïcha Kader',
    email: 'aicha@example.org',
  },
  createdAt: '2026-10-17T08:00:00.000Z',
  status: 'visible',
  statusReason: null,
};

const draft: BotDraft = {
  id: 'cbd_1',
  postId: 'cp_1',
  status: 'proposed',
  statusReason: null,
  lang: 'fr',
  intents: ['status', 'deadline'],
  entities: [{ type: 'scholarship', id: 'clx1', label: 'Bourse Eiffel', resolvedBy: 'mention' }],
  facts: { version: 1, entities: [] },
  sources: [
    {
      type: 'scholarship',
      id: 'clx1',
      label: 'Bourse Eiffel',
      url: 'https://www.campusfrance.org/fr/eiffel',
      verifiedAt: '2026-10-01T00:00:00.000Z',
      stale: false,
    },
    { type: 'institution', id: 'i1', label: 'École X', url: 'javascript:alert(1)', verifiedAt: null, stale: true },
  ],
  factsHash: 'abc',
  proposedText: 'Bonjour ! Voici ce que disent les données vérifiées de KPB.',
  writer: 'llm',
  llmFallbackReason: null,
  confidence: 'high',
  complete: true,
  scamCaution: true,
  createdAt: '2026-10-17T08:01:00.000Z',
  generatedAt: '2026-10-17T08:02:00.000Z',
  processedAt: null,
  processedBy: null,
  rejectReason: null,
  publishedReplyId: null,
  publishedVerified: false,
  autoPublished: false,
  post: { id: 'cp_1', title: 'La bourse Eiffel est-elle ouverte ?', type: 'question', status: 'visible', createdAt: '2026-10-17T08:00:00.000Z' },
};

const detail = (over: Partial<BotDraft> = {}, live = { postVisible: true, factsChanged: false }): BotDraftDetail => ({
  mode: 'review',
  draft: { ...draft, ...over },
  post,
  live,
});

function view(d: BotDraftDetail, text = d.draft.proposedText ?? '', canAct = true) {
  return render(
    <BotDraftDetailView
      detail={d}
      text={text}
      canAct={canAct}
      onTextChange={noop}
      onReset={noop}
      onPublish={noop}
      onReject={noop}
      onRegenerate={noop}
      onOpenPost={noop}
    />,
  );
}

describe('onglet « Bot Vérif » (rendu)', () => {
  it('statistiques : mode, proposés, publiés, rejetés, délai', () => {
    const stats: BotStats = {
      mode: 'review',
      llmEnabled: false,
      window: { from: '', to: '', days: 30 },
      current: { proposed: 4, obsolete: 1 },
      created: { published: 12, rejected: 3 },
      autoPublished: 0,
      publishedVerified: 5,
      llmWritten: 0,
      medianHandlingHours: 2.5,
    };
    const html = render(<BotStatsView stats={stats} />);
    expect(html).toContain('Validation humaine');
    expect(html).toContain('Le bot prépare, l&#x27;équipe publie');
    expect(html).toMatch(/À traiter<\/span><span[^>]*>4</);
    expect(html).toMatch(/Publiés \(30 j\)<\/span><span[^>]*>12</);
    expect(html).toMatch(/Rejetés \(30 j\)<\/span><span[^>]*>3</);
    expect(html).toContain('2,5 h');
    expect(html).toContain('5 publié(s) comme réponse vérifiée');
  });

  it('file : statut, confiance, entités ; vide → état vide', () => {
    const html = render(<BotDraftList items={[draft, { ...draft, id: 'cbd_2', status: 'obsolete', statusReason: 'facts_changed', confidence: null }]} selectedId="cbd_1" onSelect={noop} />);
    expect(html).toContain('Proposés');
    expect(html).toContain('Confiance haute');
    expect(html).toContain('La bourse Eiffel est-elle ouverte ?');
    expect(html).toContain('Les faits du catalogue ont changé depuis la rédaction');
    expect(html).toMatch(/data-draft-id="cbd_1" aria-pressed="true"/);
    expect(render(<BotDraftList items={[]} selectedId={null} onSelect={noop} />)).toContain('Aucun brouillon');
  });

  it('détail : question, faits avec sources cliquables (http seulement), texte éditable, quatre actions', () => {
    const html = view(detail());
    expect(html).toContain('Bourse Eiffel');
    expect(html).toContain('<mark');
    expect(html).toContain('Ce qui est demandé');
    expect(html).toContain('Date limite');
    expect(html).toContain('href="https://www.campusfrance.org/fr/eiffel" target="_blank" rel="noopener noreferrer"');
    expect(html).not.toContain('javascript:');
    expect(html).toContain('Vérifiée le 01/10/2026');
    expect(html).toContain('À revérifier');
    expect(html).toContain('mentionnée par l&#x27;élève');
    expect(html).toContain('Phrase de prudence anti-arnaque');
    expect(html).toContain('Reformulée par l&#x27;IA (contrôlée)');
    expect(html).toContain('<textarea');
    expect(html).not.toMatch(/<textarea[^>]*readonly/i);
    for (const label of ['Publier', 'Publier et marquer vérifiée', 'Rejeter', 'Régénérer']) expect(html).toContain(`>${label}</button>`);
    expect(html).not.toContain('data-stale');
    // L'identité réelle de l'élève n'apparaît jamais dans l'onglet du bot.
    expect(html).not.toContain('aicha@example.org');
  });

  it('obsolète : bandeau, publication désactivée (faits changés en direct, ou statut)', () => {
    const live = view(detail({}, { postVisible: true, factsChanged: true }));
    expect(live).toContain('data-stale="true"');
    expect(live).toContain('Les faits du catalogue ont changé depuis la rédaction');
    expect(live).toMatch(/<button[^>]*disabled=""[^>]*>Publier<\/button>/);
    const hidden = view(detail({ status: 'obsolete', statusReason: 'post_not_visible' }));
    expect(hidden).toContain('La publication n&#x27;est plus visible');
    expect(hidden).toMatch(/<button[^>]*disabled=""[^>]*>Publier et marquer vérifiée<\/button>/);
    expect(hidden).not.toMatch(/<button[^>]*disabled=""[^>]*>Régénérer<\/button>/);
  });

  it('texte vide : erreur, publication désactivée ; texte modifié : « Revenir au texte proposé »', () => {
    const empty = view(detail(), '  ');
    expect(empty).toContain('role="alert"');
    expect(empty).toMatch(/<button[^>]*disabled=""[^>]*>Publier<\/button>/);
    expect(view(detail(), 'Texte relu par l’équipe')).toContain('Revenir au texte proposé');
  });

  it('publié / rejeté : trace, lecture seule ; sans droit d’agir : aucun bouton', () => {
    const published = view(
      detail({ status: 'published', processedAt: '2026-10-17T09:00:00.000Z', processedBy: { adminId: 'a1', name: 'Fatou Diallo' }, publishedVerified: true }),
    );
    expect(published).toContain('Publié le');
    expect(published).toContain('Fatou Diallo');
    expect(published).toMatch(/<textarea[^>]*readonly/i);
    const rejected = view(detail({ status: 'rejected', rejectReason: 'Hors sujet', processedBy: { adminId: 'a1', name: 'Fatou Diallo' } }));
    expect(rejected).toContain('Hors sujet');
    expect(view(detail(), undefined, false)).not.toContain('>Publier</button>');
  });

  it('valeurs inconnues (révision future) : affichées brutes, sans casser', () => {
    const html = view(detail({ status: 'statut_futur', confidence: 'tres_haute', intents: ['nouveau_motif'], writer: 'autre' }));
    expect(html).toContain('statut futur');
    expect(html).toContain('nouveau motif');
  });
});
