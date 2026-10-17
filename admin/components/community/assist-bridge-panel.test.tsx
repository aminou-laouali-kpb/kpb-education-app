import { ReactElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';

import type { AssistCatalog, AssistCounts, AssistEvent, AssistStats } from '../../lib/community-admin';
import { LocaleProvider } from '../locale-provider';
import { AssistCatalogView, AssistEventList, AssistStatsView } from './assist-bridge-panel';

// Rendu serveur (effets non exécutés), même méthode que bot-panel.test.tsx.
function render(element: ReactElement): string {
  return renderToStaticMarkup(<LocaleProvider>{element}</LocaleProvider>);
}

const noop = () => {};

const counts = (over: Partial<AssistCounts> = {}): AssistCounts => ({
  detected: 0,
  pending: 0,
  sent: 0,
  wouldSend: 0,
  skipped: {},
  openedFeature: 0,
  openedWhatsapp: 0,
  dismissed: 0,
  ...over,
});

const event = (over: Partial<AssistEvent> = {}): AssistEvent => ({
  id: 'abe_1',
  source: 'community_post',
  needId: 'scholarship_match',
  ruleId: 'scholarship_match.which',
  ruleVersion: 'ab-1',
  status: 'sent',
  statusReason: null,
  mode: 'on',
  pushOutcome: 'pushed',
  createdAt: '2026-10-17T08:00:00.000Z',
  processedAt: '2026-10-17T08:01:00.000Z',
  sentAt: '2026-10-17T08:01:00.000Z',
  openedFeatureAt: null,
  openedWhatsappAt: null,
  dismissedAt: null,
  excerpt: 'Quelle bourse pour moi ?',
  postId: 'cp_1',
  ...over,
});

describe('onglet « Bot Passerelle » (rendu)', () => {
  it('statistiques : mode shadow, source coach fermée, tuiles et tableau par besoin', () => {
    const stats: AssistStats = {
      mode: 'shadow',
      coachSource: false,
      rulesVersion: 'ab-1',
      window: { from: '', to: '', days: 30 },
      totals: counts({ detected: 12, wouldSend: 5, skipped: { shadow: 5, user_cap: 3 } }),
      bySource: { community_post: 10, community_reply: 2, coach_message: 0 },
      needs: [
        { needId: 'scholarship_match', label: { fr: 'Trouver une bourse', en: 'Find a scholarship' }, ...counts({ detected: 7, wouldSend: 3, skipped: { shadow: 3, need_cooldown: 2 } }) },
        { needId: 'besoin_futur', label: { fr: 'x', en: 'x' }, ...counts({ detected: 1 }) },
      ],
    };
    const html = render(<AssistStatsView stats={stats} />);
    expect(html).toContain('Observation (rien n&#x27;est envoyé)');
    expect(html).toContain('Source coach fermée');
    expect(html).toContain('Catalogue ab-1');
    expect(html).toMatch(/Détectés<\/span><span[^>]*>12</);
    expect(html).toMatch(/Envois simulés<\/span><span[^>]*>5</);
    expect(html).toContain('data-need="scholarship_match"');
    expect(html).toContain('Trouver une bourse');
    expect(html).toContain('Observation (non envoyé) : 3 · Même besoin &lt; 30 jours : 2');
    // Besoin inconnu (catalogue futur) : affiché brut, sans casser.
    expect(html).toContain('besoin futur');
  });

  it('événements : extrait pour un contenu public, AUCUN texte pour le coach, lien vers la discussion', () => {
    const html = render(
      <AssistEventList
        items={[
          event(),
          event({ id: 'abe_2', source: 'coach_message', needId: 'visa', excerpt: 'texte privé fuité', postId: 'cp_9', status: 'skipped', statusReason: 'user_cap' }),
          event({ id: 'abe_3', source: 'community_reply', excerpt: null, postId: null, status: 'opened_whatsapp' }),
        ]}
        onOpenPost={noop}
      />,
    );
    expect(html).toContain('« Quelle bourse pour moi ? »');
    expect(html).toContain('Ouvrir la discussion');
    expect(html).toContain('Message privé au coach : aucun texte n&#x27;est conservé ni affiché.');
    expect(html).not.toContain('texte privé fuité');
    expect(html).toContain('Déjà notifié &lt; 72 h');
    expect(html).toContain('Contenu plus visible : pas d&#x27;extrait.');
    expect(html).toContain('WhatsApp ouvert');
    // Un seul bouton « Ouvrir la discussion » : jamais pour le coach.
    expect(html.match(/Ouvrir la discussion/g)).toHaveLength(1);
    expect(render(<AssistEventList items={[]} onOpenPost={noop} />)).toContain('Aucun événement');
  });

  it('catalogue : besoins, fonction cible et route, textes FR/EN, règles', () => {
    const catalog: AssistCatalog = {
      mode: 'on',
      coachSource: true,
      version: 'ab-1',
      minWords: 4,
      needs: [
        {
          id: 'document_review',
          label: { fr: 'Relecture CV / lettre de motivation', en: 'CV / cover letter review' },
          feature: 'document_review',
          featureLabel: { fr: 'Outils → Relecture de document (IA)', en: 'Tools → Document review (AI)' },
          route: '/document-review',
          rules: [{ id: 'document_review.review', selfAsking: false }],
          title: { fr: 'Ton CV ou ta lettre, relus dans l’app', en: 'Your CV or letter, reviewed in the app' },
          body: { fr: 'Tu peux déjà faire relire ton CV.', en: 'You can already get your CV reviewed.' },
        },
      ],
    };
    const html = render(<AssistCatalogView catalog={catalog} />);
    expect(html).toContain('Version ab-1 · au moins 4 mots par message');
    expect(html).toContain('Fonction : Outils → Relecture de document (IA) · route /document-review');
    expect(html).toContain('Ton CV ou ta lettre, relus dans l’app');
    expect(html).toContain('Your CV or letter, reviewed in the app');
    expect(html).toContain('document_review.review');
  });
});
