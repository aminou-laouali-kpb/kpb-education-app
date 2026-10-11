'use client';

import { CSSProperties } from 'react';

import { Button, Field, Input, Select, Textarea } from '../ui';
import {
  DEGREE_LEVELS,
  labelOf,
  type CatalogCountry,
  type CatalogField,
  type CatalogInstitution,
} from '../../lib/catalog-admin-api';
import type { InstitutionDraft, ProgramDraft } from '../../lib/catalog-form';

const gridStyle: CSSProperties = {
  display: 'grid',
  gap: 12,
  gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))',
};

const sectionStyle: CSSProperties = {
  display: 'grid',
  gap: 12,
  padding: 16,
  background: 'var(--surface)',
  border: '1px solid var(--border)',
  borderRadius: 16,
};

function countryLabel(countries: CatalogCountry[], id: string): string {
  const match = countries.find((c) => c.id === id);
  return match ? labelOf(match) : id;
}

const hintStyle: CSSProperties = {
  fontSize: 12,
  color: 'var(--text-muted, #64748b)',
  margin: 0,
};

export function InstitutionForm({
  draft,
  countries,
  pending,
  editing,
  programCount,
  onChange,
  onSubmit,
  onCancel,
}: {
  draft: InstitutionDraft;
  countries: CatalogCountry[];
  pending: boolean;
  editing: boolean;
  /**
   * Nombre de formations rattachées, ou `null` tant qu'il n'est pas connu.
   * Au-delà de zéro, le pays est verrouillé : `Program.countryId` est stocké
   * indépendamment et ne suivrait PAS le déplacement de l'établissement. Les
   * formations resteraient filtrées et notées sous l'ancien pays, sans que rien
   * ne le signale.
   */
  programCount: number | null;
  onChange: (patch: Partial<InstitutionDraft>) => void;
  onSubmit: () => void;
  onCancel: () => void;
}) {
  // Compte encore inconnu (chargement) ⇒ verrouillé : `(null ?? 0) > 0`
  // déverrouillait le pays pendant le chargement. Le serveur refuse de toute
  // façon un déplacement qui laisserait des formations sous l'ancien pays.
  const countryLocked = editing && (programCount === null || programCount > 0);
  return (
    <div style={sectionStyle}>
      <div style={gridStyle}>
        <Field label="Nom (FR) *">
          {({ id }) => (
            <Input
              id={id}
              value={draft.nameFr}
              onChange={(e) => onChange({ nameFr: e.target.value })}
            />
          )}
        </Field>
        <Field label="Nom (EN)">
          {({ id }) => (
            <Input
              id={id}
              value={draft.nameEn}
              placeholder="Repris du FR si vide"
              onChange={(e) => onChange({ nameEn: e.target.value })}
            />
          )}
        </Field>
        {/*
          Liste déroulante, jamais de saisie libre : `countryId` n'est pas une
          clé étrangère en base. Un identifiant erroné crée une fiche que rien
          ne signale et qui ne remonte sous aucun filtre.
        */}
        <Field label="Pays *">
          {({ id }) =>
            countryLocked ? (
              <>
                <Input
                  id={id}
                  readOnly
                  value={`${countryLabel(countries, draft.countryId)} (${draft.countryId})`}
                />
                <p style={hintStyle}>
                  Verrouillé : {programCount} formation(s) y sont rattachées et
                  garderaient l’ancien pays. Déplacer l’école demande de
                  déplacer ses formations, ce que cet écran ne sait pas faire.
                </p>
              </>
            ) : (
              <Select
                id={id}
                value={draft.countryId}
                onChange={(e) => onChange({ countryId: e.target.value })}
              >
                <option value="">— choisir —</option>
                {countries.map((c) => (
                  <option key={c.id} value={c.id}>
                    {labelOf(c)} ({c.id})
                  </option>
                ))}
              </Select>
            )
          }
        </Field>
        <Field label="Ville / campus">
          {({ id }) => (
            <Input
              id={id}
              value={draft.locationFr}
              placeholder="Casablanca · Nouaceur"
              onChange={(e) => onChange({ locationFr: e.target.value })}
            />
          )}
        </Field>
        <Field label="Frais (libellé affiché)">
          {({ id }) => (
            <Input
              id={id}
              value={draft.tuitionLabelFr}
              onChange={(e) => onChange({ tuitionLabelFr: e.target.value })}
            />
          )}
        </Field>
        <Field label="Exigences linguistiques">
          {({ id }) => (
            <Input
              id={id}
              value={draft.languageRequirementsFr}
              onChange={(e) =>
                onChange({ languageRequirementsFr: e.target.value })
              }
            />
          )}
        </Field>
        <Field label="Rentrées (séparées par des virgules)">
          {({ id }) => (
            <Input
              id={id}
              value={draft.intakePeriods}
              placeholder="Septembre, Février"
              onChange={(e) => onChange({ intakePeriods: e.target.value })}
            />
          )}
        </Field>
      </div>

      <Field label="Présentation">
        {({ id }) => (
          <Textarea
            id={id}
            rows={3}
            value={draft.overviewFr}
            onChange={(e) => onChange({ overviewFr: e.target.value })}
          />
        )}
      </Field>

      <fieldset style={{ border: 0, padding: 0, margin: 0 }}>
        <legend style={{ fontSize: 13, fontWeight: 600, marginBottom: 6 }}>
          Niveaux proposés
        </legend>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12 }}>
          {DEGREE_LEVELS.map((level) => (
            <label key={level} style={{ display: 'flex', gap: 6, fontSize: 13 }}>
              <input
                type="checkbox"
                checked={draft.studyLevels.includes(level)}
                onChange={(e) =>
                  onChange({
                    studyLevels: e.target.checked
                      ? [...draft.studyLevels, level]
                      : draft.studyLevels.filter((l) => l !== level),
                  })
                }
              />
              {level}
            </label>
          ))}
        </div>
      </fieldset>

      <label style={{ display: 'flex', gap: 8, fontSize: 13 }}>
        <input
          type="checkbox"
          checked={draft.isPartner}
          onChange={(e) => onChange({ isPartner: e.target.checked })}
        />
        Établissement partenaire
      </label>

      <div style={{ display: 'flex', gap: 8 }}>
        <Button onClick={onSubmit} loading={pending}>
          {editing ? 'Enregistrer' : 'Créer'}
        </Button>
        <Button variant="ghost" onClick={onCancel} disabled={pending}>
          Annuler
        </Button>
      </div>
    </div>
  );
}

export function ProgramForm({
  draft,
  countries,
  fields,
  institutions,
  pending,
  editing,
  onChange,
  onSubmit,
  onCancel,
}: {
  draft: ProgramDraft;
  countries: CatalogCountry[];
  fields: CatalogField[];
  institutions: CatalogInstitution[];
  pending: boolean;
  editing: boolean;
  onChange: (patch: Partial<ProgramDraft>) => void;
  onSubmit: () => void;
  onCancel: () => void;
}) {
  return (
    <div style={sectionStyle}>
      <div style={gridStyle}>
        <Field label="Établissement *">
          {({ id }) => (
            <Select
              id={id}
              value={draft.institutionId}
              onChange={(e) => {
                const inst = institutions.find((i) => i.id === e.target.value);
                // Le pays suit l'établissement : un programme rattaché à un
                // autre pays que le sien ne remonterait sous aucun filtre.
                onChange({
                  institutionId: e.target.value,
                  ...(inst ? { countryId: inst.countryId } : {}),
                });
              }}
            >
              <option value="">— choisir —</option>
              {institutions.map((i) => (
                <option key={i.id} value={i.id}>
                  {i.name.fr}
                </option>
              ))}
            </Select>
          )}
        </Field>
        {/*
          LECTURE SEULE, dérivé de l'établissement.

          `Program.countryId` est stocké indépendamment, et c'est LUI que
          filtrent le catalogue public et le service de matching. Un champ
          modifiable laissait créer une formation rattachée à une école
          marocaine mais affichée et notée sous la France. Vérifié sur les 628
          programmes de production : aucun ne diverge du pays de son
          établissement — il n'y a donc aucun cas légitime à préserver.
        */}
        <Field label="Pays">
          {({ id }) => (
            <Input
              id={id}
              readOnly
              value={
                draft.countryId
                  ? `${countryLabel(countries, draft.countryId)} (${draft.countryId})`
                  : '— suit l’établissement —'
              }
            />
          )}
        </Field>
        <Field label="Filière *">
          {({ id }) => (
            <Select
              id={id}
              value={draft.fieldId}
              onChange={(e) => onChange({ fieldId: e.target.value })}
            >
              <option value="">— choisir —</option>
              {fields.map((f) => (
                <option key={f.id} value={f.id}>
                  {labelOf(f)} ({f.id})
                </option>
              ))}
            </Select>
          )}
        </Field>
        <Field label="Nom (FR) *">
          {({ id }) => (
            <Input
              id={id}
              value={draft.nameFr}
              onChange={(e) => onChange({ nameFr: e.target.value })}
            />
          )}
        </Field>
        <Field label="Nom (EN)">
          {({ id }) => (
            <Input
              id={id}
              value={draft.nameEn}
              placeholder="Repris du FR si vide"
              onChange={(e) => onChange({ nameEn: e.target.value })}
            />
          )}
        </Field>
        {/*
          Liste fermée : `normalizeDegreeLevel` laisse passer TEL QUEL ce qu'il
          ne reconnaît pas. Une saisie libre ferait apparaître « Prépa » ou
          « 1re année » dans le filtre par niveau de l'app — c'est arrivé à
          l'import Mundiapolis, 4 valeurs hors référentiel sont en production.
        */}
        <Field label="Niveau">
          {({ id }) => (
            <Select
              id={id}
              value={draft.levelFr}
              onChange={(e) => onChange({ levelFr: e.target.value })}
            >
              <option value="">— non précisé —</option>
              {DEGREE_LEVELS.map((level) => (
                <option key={level} value={level}>
                  {level}
                </option>
              ))}
            </Select>
          )}
        </Field>
        <Field label="Durée">
          {({ id }) => (
            <Input
              id={id}
              value={draft.durationFr}
              placeholder="3 ans (Bac+3)"
              onChange={(e) => onChange({ durationFr: e.target.value })}
            />
          )}
        </Field>
        <Field label="Frais (libellé affiché)">
          {({ id }) => (
            <Input
              id={id}
              value={draft.tuitionFr}
              placeholder="8 850 €/an"
              onChange={(e) => onChange({ tuitionFr: e.target.value })}
            />
          )}
        </Field>
        <Field label="Langue (libellé affiché)">
          {({ id }) => (
            <Input
              id={id}
              value={draft.languageFr}
              placeholder="Français"
              onChange={(e) => onChange({ languageFr: e.target.value })}
            />
          )}
        </Field>
      </div>

      <Field label="Prérequis (séparés par des virgules)">
        {({ id }) => (
          <Input
            id={id}
            value={draft.requirementsFr}
            onChange={(e) => onChange({ requirementsFr: e.target.value })}
          />
        )}
      </Field>

      <div style={{ ...sectionStyle, background: 'var(--surface-muted, #f8fafc)' }}>
        <div>
          <strong style={{ fontSize: 13 }}>Probabilité d’admission</strong>
          <p style={hintStyle}>
            Ces quatre champs alimentent le score affiché dans l’app. Laissés
            vides, le facteur correspondant est neutralisé et le match est
            présenté comme une estimation.
          </p>
        </div>
        <div style={gridStyle}>
          <Field label="Moyenne minimale (/20)">
            {({ id }) => (
              <Input
                id={id}
                inputMode="decimal"
                value={draft.minGpaRequired}
                placeholder="12.5"
                onChange={(e) => onChange({ minGpaRequired: e.target.value })}
              />
            )}
          </Field>
          <Field label="Plancher de frais (€/an)">
            {({ id }) => (
              <Input
                id={id}
                inputMode="numeric"
                value={draft.tuitionMinEur}
                placeholder="6690"
                onChange={(e) => onChange({ tuitionMinEur: e.target.value })}
              />
            )}
          </Field>
          <Field label="Date limite de candidature">
            {({ id }) => (
              <Input
                id={id}
                type="date"
                value={draft.applicationDeadline}
                onChange={(e) =>
                  onChange({ applicationDeadline: e.target.value })
                }
              />
            )}
          </Field>
          <Field label="Langues d’enseignement (codes)">
            {({ id }) => (
              <Input
                id={id}
                value={draft.teachingLanguages}
                placeholder="fr, en"
                onChange={(e) =>
                  onChange({ teachingLanguages: e.target.value })
                }
              />
            )}
          </Field>
        </div>
      </div>

      <div style={{ display: 'flex', gap: 8 }}>
        <Button onClick={onSubmit} loading={pending}>
          {editing ? 'Enregistrer' : 'Créer'}
        </Button>
        <Button variant="ghost" onClick={onCancel} disabled={pending}>
          Annuler
        </Button>
      </div>
    </div>
  );
}
