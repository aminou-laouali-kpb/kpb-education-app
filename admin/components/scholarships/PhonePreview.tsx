'use client';

import { CSSProperties, useState } from 'react';

import {
  phoneCopy,
  phoneTabMessageKey,
  phoneTabs,
  type PhoneTab,
} from '../../lib/scholarship-opening';
import type {
  LocalizedPushCopy,
  OpeningAudienceScope,
  OpeningPreviewCopy,
} from '../../lib/scholarship-opening-types';
import { useLocale } from '../locale-provider';
import { Button } from '../ui';

/**
 * Maquette de la notification telle que l'étudiant la verra, en français et
 * en anglais côte à côte (la langue est choisie à l'envoi d'après le profil).
 * Le texte vient tel quel de l'aperçu du serveur : c'est celui qui partira.
 */

// L'horodatage affiché par le téléphone, dans la langue de la carte (pas dans
// celle de l'équipe) : c'est un morceau de la maquette, pas de l'interface.
const NOW_LABEL: Record<'fr' | 'en', string> = { fr: 'maintenant', en: 'now' };

const cardStyle: CSSProperties = {
  display: 'grid',
  gap: 6,
  padding: 12,
  borderRadius: 16,
  background: 'var(--surface)',
  border: '1px solid var(--border)',
  boxShadow: 'var(--shadow-sm)',
};

const iconStyle: CSSProperties = {
  display: 'grid',
  placeItems: 'center',
  width: 20,
  height: 20,
  borderRadius: 6,
  background: 'var(--brand)',
  color: 'var(--brand-fg)',
  fontSize: 7.5,
  fontWeight: 800,
  letterSpacing: '0.02em',
};

const metaLabelStyle: CSSProperties = {
  fontSize: 9.5,
  fontWeight: 800,
  letterSpacing: '0.06em',
  textTransform: 'uppercase',
  color: 'var(--text-faint)',
};

function NotificationCard({
  language,
  label,
  copy,
}: Readonly<{ language: 'fr' | 'en'; label: string; copy: LocalizedPushCopy }>) {
  return (
    <figure style={{ margin: 0, display: 'grid', gap: 6, minWidth: 0 }} lang={language}>
      <figcaption style={metaLabelStyle}>{label}</figcaption>
      <div
        style={{
          padding: 10,
          borderRadius: 22,
          background: 'var(--surface-2)',
          border: '1px solid var(--border)',
        }}
      >
        <div style={cardStyle}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <span style={iconStyle} aria-hidden="true">
              KPB
            </span>
            <span style={{ fontSize: 'var(--text-xs)', color: 'var(--text-muted)', flex: 1 }}>
              KPB Education
            </span>
            <span style={{ fontSize: 'var(--text-xs)', color: 'var(--text-faint)' }}>
              {NOW_LABEL[language]}
            </span>
          </div>
          <strong style={{ fontSize: 'var(--text-sm)', color: 'var(--ink)' }}>
            {copy.title}
          </strong>
          <span
            style={{
              fontSize: 'var(--text-sm)',
              color: 'var(--text)',
              lineHeight: 1.45,
              overflowWrap: 'anywhere',
            }}
          >
            {copy.body}
          </span>
        </div>
      </div>
    </figure>
  );
}

export function PhonePreview({
  copy,
  scope,
}: Readonly<{ copy: OpeningPreviewCopy; scope: OpeningAudienceScope }>) {
  const { t } = useLocale();
  const tabs = phoneTabs(copy.variant, scope);
  const [tab, setTab] = useState<PhoneTab>(tabs[0]);
  // La variante ou la portée peut changer d'un aperçu à l'autre (dates
  // modifiées, bascule de mode) : un onglet disparu revient au premier.
  const active = tabs.includes(tab) ? tab : tabs[0];
  const texts = phoneCopy(copy, active);

  return (
    <div style={{ display: 'grid', gap: 10 }}>
      <div
        role="tablist"
        aria-label={t('scholarships.opening.phoneTitle')}
        style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}
      >
        {tabs.map((value) => (
          <Button
            key={value}
            size="sm"
            role="tab"
            aria-selected={value === active}
            variant={value === active ? 'primary' : 'secondary'}
            onClick={() => setTab(value)}
          >
            {t(phoneTabMessageKey(value))}
          </Button>
        ))}
      </div>
      <div
        role="tabpanel"
        style={{
          display: 'grid',
          gap: 12,
          gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
        }}
      >
        <NotificationCard
          language="fr"
          label={t('scholarships.opening.phoneFrench')}
          copy={texts.fr}
        />
        <NotificationCard
          language="en"
          label={t('scholarships.opening.phoneEnglish')}
          copy={texts.en}
        />
      </div>
    </div>
  );
}
