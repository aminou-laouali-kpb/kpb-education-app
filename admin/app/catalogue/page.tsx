'use client';

import { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';

import { DashboardShell } from '../../components/dashboard-shell';
import {
  InstitutionForm,
  ProgramForm,
} from '../../components/catalogue/CatalogueForms';
import {
  AdminTable,
  AdminTableRow,
  Alert,
  Badge,
  Button,
  CellText,
  ConfirmDialog,
  EmptyState,
  Select,
} from '../../components/ui';
import {
  createInstitution,
  createProgram,
  deleteInstitution,
  deleteProgram,
  fetchCountries,
  fetchFields,
  fetchInstitutions,
  fetchPrograms,
  labelOf,
  updateInstitution,
  updateProgram,
  type CatalogCountry,
  type CatalogField,
  type CatalogInstitution,
  type CatalogProgram,
} from '../../lib/catalog-admin-api';
import {
  DraftError,
  EMPTY_INSTITUTION_DRAFT,
  EMPTY_PROGRAM_DRAFT,
  toInstitutionInput,
  toProgramInput,
  type InstitutionDraft,
  type ProgramDraft,
} from '../../lib/catalog-form';

type Tab = 'institutions' | 'programs';

const barStyle: CSSProperties = {
  display: 'flex',
  gap: 8,
  flexWrap: 'wrap',
  alignItems: 'center',
  marginBottom: 16,
};

function messageOf(error: unknown): string {
  if (error instanceof DraftError) return error.message;
  if (error instanceof Error) return error.message;
  return 'Erreur inattendue.';
}

export default function CataloguePage() {
  const [tab, setTab] = useState<Tab>('institutions');

  const [countries, setCountries] = useState<CatalogCountry[]>([]);
  const [fields, setFields] = useState<CatalogField[]>([]);
  const [institutions, setInstitutions] = useState<CatalogInstitution[]>([]);
  const [programs, setPrograms] = useState<CatalogProgram[]>([]);

  const [countryFilter, setCountryFilter] = useState('');
  const [institutionFilter, setInstitutionFilter] = useState('');

  const [loading, setLoading] = useState(true);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<string | null>(null);

  const [instDraft, setInstDraft] = useState<InstitutionDraft | null>(null);
  const [instEditingId, setInstEditingId] = useState<string | null>(null);
  // `null` = pas encore connu. Décide du verrouillage du pays : déplacer une
  // école laisserait ses formations sous l'ancien pays.
  const [instProgramCount, setInstProgramCount] = useState<number | null>(null);
  const [progDraft, setProgDraft] = useState<ProgramDraft | null>(null);
  const [progEditingId, setProgEditingId] = useState<string | null>(null);
  const [confirming, setConfirming] = useState<
    { kind: Tab; id: string; label: string } | null
  >(null);

  const loadReferentials = useCallback(async () => {
    const [c, f] = await Promise.all([fetchCountries(), fetchFields()]);
    setCountries(c);
    setFields(f);
  }, []);

  const loadInstitutions = useCallback(async (countryId: string) => {
    setInstitutions(await fetchInstitutions(countryId ? { countryId } : {}));
  }, []);

  const loadPrograms = useCallback(async (institutionId: string) => {
    // Sans établissement choisi, la liste complète dépasse largement ce qu'un
    // écran sert utilement : on borne, et le filtre reste le vrai outil.
    setPrograms(
      await fetchPrograms(
        institutionId ? { institutionId, limit: 500 } : { limit: 100 },
      ),
    );
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      setError(null);
      try {
        await loadReferentials();
        await loadInstitutions('');
        if (!cancelled) setLoading(false);
      } catch (e) {
        if (!cancelled) {
          setError(messageOf(e));
          setLoading(false);
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [loadReferentials, loadInstitutions]);

  useEffect(() => {
    if (tab !== 'programs') return;
    loadPrograms(institutionFilter).catch((e) => setError(messageOf(e)));
  }, [tab, institutionFilter, loadPrograms]);

  async function run(action: () => Promise<void>, ok: string) {
    setPending(true);
    setError(null);
    setStatus(null);
    try {
      await action();
      setStatus(ok);
    } catch (e) {
      setError(messageOf(e));
    } finally {
      setPending(false);
    }
  }

  const instCountRequest = useRef<string | null>(null);

  function startInstitutionEdit(entry: CatalogInstitution) {
    setInstEditingId(entry.id);
    setInstProgramCount(null);
    // Seule la réponse de l'édition EN COURS compte : celle d'une fiche ouverte
    // juste avant pouvait arriver après et écraser le compte.
    instCountRequest.current = entry.id;
    fetchPrograms({ institutionId: entry.id, limit: 500 })
      .then((rows) => {
        if (instCountRequest.current === entry.id) setInstProgramCount(rows.length);
      })
      // Compte inconnu ⇒ on verrouille, plutôt que d'autoriser un déplacement
      // dont on ne peut pas mesurer les dégâts.
      .catch(() => {
        if (instCountRequest.current === entry.id) setInstProgramCount(1);
      });
    setInstDraft({
      nameFr: entry.name.fr,
      nameEn: entry.name.en,
      countryId: entry.countryId,
      locationFr: entry.location.fr,
      overviewFr: entry.overview.fr,
      studyLevels: entry.studyLevels,
      tuitionLabelFr: entry.tuitionLabel.fr,
      languageRequirementsFr: entry.languageRequirements.fr,
      intakePeriods: entry.intakePeriods.join(', '),
      isPartner: entry.isPartner,
    });
  }

  function startProgramEdit(entry: CatalogProgram) {
    setProgEditingId(entry.id);
    setProgDraft({
      institutionId: entry.institutionId,
      countryId: entry.countryId,
      fieldId: entry.fieldId,
      nameFr: entry.nameFr,
      nameEn: entry.nameEn,
      levelFr: entry.levelFr,
      durationFr: entry.durationFr,
      tuitionFr: entry.tuitionFr,
      languageFr: entry.languageFr,
      requirementsFr: entry.requirementsFr.join(', '),
      minGpaRequired: entry.minGpaRequired?.toString() ?? '',
      tuitionMinEur: entry.tuitionMinEur?.toString() ?? '',
      // Le backend rend un instant ISO complet ; `<input type="date">` n'accepte
      // que la partie calendaire.
      applicationDeadline: entry.applicationDeadline?.slice(0, 10) ?? '',
      teachingLanguages: entry.teachingLanguages.join(', '),
    });
  }

  const instName = (id: string) =>
    institutions.find((i) => i.id === id)?.name.fr ?? id;

  return (
    <DashboardShell
      title="Catalogue"
      subtitle="Universités et formations servies à l’app"
    >
      {error ? <Alert variant="danger">{error}</Alert> : null}
      {status ? <Alert variant="success">{status}</Alert> : null}

      <div style={barStyle}>
        <Button
          variant={tab === 'institutions' ? 'primary' : 'ghost'}
          onClick={() => setTab('institutions')}
        >
          Universités ({institutions.length})
        </Button>
        <Button
          variant={tab === 'programs' ? 'primary' : 'ghost'}
          onClick={() => setTab('programs')}
        >
          Formations
        </Button>
      </div>

      {tab === 'institutions' ? (
        <>
          <div style={barStyle}>
            <Select
              value={countryFilter}
              onChange={(e) => {
                setCountryFilter(e.target.value);
                loadInstitutions(e.target.value).catch((err) =>
                  setError(messageOf(err)),
                );
              }}
            >
              <option value="">Tous les pays</option>
              {countries.map((c) => (
                <option key={c.id} value={c.id}>
                  {labelOf(c)}
                </option>
              ))}
            </Select>
            <Button
              onClick={() => {
                setInstEditingId(null);
                setInstProgramCount(0);
                setInstDraft({ ...EMPTY_INSTITUTION_DRAFT });
              }}
            >
              Nouvelle université
            </Button>
          </div>

          {instDraft ? (
            <InstitutionForm
              draft={instDraft}
              countries={countries}
              pending={pending}
              editing={instEditingId != null}
              programCount={instProgramCount}
              onChange={(patch) =>
                setInstDraft((d) => (d ? { ...d, ...patch } : d))
              }
              onCancel={() => {
                setInstDraft(null);
                setInstEditingId(null);
              }}
              onSubmit={() =>
                run(async () => {
                  const payload = toInstitutionInput(
                    instDraft,
                    instEditingId ? 'edit' : 'create',
                  );
                  if (instEditingId) await updateInstitution(instEditingId, payload);
                  else await createInstitution(payload);
                  setInstDraft(null);
                  setInstEditingId(null);
                  await loadInstitutions(countryFilter);
                }, instEditingId ? 'Université enregistrée.' : 'Université créée.')
              }
            />
          ) : null}

          {loading ? (
            <EmptyState title="Chargement…" />
          ) : institutions.length === 0 ? (
            <EmptyState title="Aucune université pour ce filtre." />
          ) : (
            <AdminTable
              columns={['Nom', 'Pays', 'Niveaux', 'Actions']}
              cols="2fr 1fr 2fr auto"
            >
              {institutions.map((entry) => (
                <AdminTableRow key={entry.id}>
                  <CellText primary={entry.name.fr} sub={entry.location.fr} />
                  <CellText primary={entry.countryId} />
                  <CellText
                    primary={entry.studyLevels.join(' · ') || '—'}
                    muted={entry.studyLevels.length === 0}
                  />
                  <div style={{ display: 'flex', gap: 6 }}>
                    {entry.isPartner ? <Badge variant="success">Partenaire</Badge> : null}
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => startInstitutionEdit(entry)}
                    >
                      Modifier
                    </Button>
                    <Button
                      size="sm"
                      variant="dangerOutline"
                      onClick={() =>
                        setConfirming({
                          kind: 'institutions',
                          id: entry.id,
                          label: entry.name.fr,
                        })
                      }
                    >
                      Supprimer
                    </Button>
                  </div>
                </AdminTableRow>
              ))}
            </AdminTable>
          )}
        </>
      ) : (
        <>
          <div style={barStyle}>
            <Select
              value={institutionFilter}
              onChange={(e) => setInstitutionFilter(e.target.value)}
            >
              <option value="">Toutes les universités (100 premières)</option>
              {institutions.map((i) => (
                <option key={i.id} value={i.id}>
                  {i.name.fr}
                </option>
              ))}
            </Select>
            <Button
              onClick={() => {
                setProgEditingId(null);
                setProgDraft({
                  ...EMPTY_PROGRAM_DRAFT,
                  institutionId: institutionFilter,
                  countryId:
                    institutions.find((i) => i.id === institutionFilter)
                      ?.countryId ?? '',
                });
              }}
            >
              Nouvelle formation
            </Button>
          </div>

          {progDraft ? (
            <ProgramForm
              draft={progDraft}
              countries={countries}
              fields={fields}
              institutions={institutions}
              pending={pending}
              editing={progEditingId != null}
              onChange={(patch) =>
                setProgDraft((d) => (d ? { ...d, ...patch } : d))
              }
              onCancel={() => {
                setProgDraft(null);
                setProgEditingId(null);
              }}
              onSubmit={() =>
                run(async () => {
                  const payload = toProgramInput(
                    progDraft,
                    progEditingId ? 'edit' : 'create',
                  );
                  if (progEditingId) await updateProgram(progEditingId, payload);
                  else await createProgram(payload);
                  setProgDraft(null);
                  setProgEditingId(null);
                  await loadPrograms(institutionFilter);
                }, progEditingId ? 'Formation enregistrée.' : 'Formation créée.')
              }
            />
          ) : null}

          {programs.length === 0 ? (
            <EmptyState title="Aucune formation pour ce filtre." />
          ) : (
            <AdminTable
              columns={['Formation', 'Niveau', 'Frais', 'Score', 'Actions']}
              cols="2fr 1fr 1fr 1fr auto"
            >
              {programs.map((entry) => (
                <AdminTableRow key={entry.id}>
                  <CellText
                    primary={entry.nameFr}
                    sub={instName(entry.institutionId)}
                  />
                  <CellText primary={entry.levelFr || '—'} />
                  <CellText primary={entry.tuitionFr || '—'} />
                  {/*
                    Rend visible ce qui, jusqu'ici, ne l'était nulle part : un
                    programme sans plancher en euros est classé sur un facteur
                    neutre et présenté comme une estimation dans l'app.
                  */}
                  <CellText
                    primary={
                      entry.tuitionMinEur != null
                        ? `${entry.tuitionMinEur} €`
                        : 'estimation'
                    }
                    muted={entry.tuitionMinEur == null}
                  />
                  <div style={{ display: 'flex', gap: 6 }}>
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => startProgramEdit(entry)}
                    >
                      Modifier
                    </Button>
                    <Button
                      size="sm"
                      variant="dangerOutline"
                      onClick={() =>
                        setConfirming({
                          kind: 'programs',
                          id: entry.id,
                          label: entry.nameFr,
                        })
                      }
                    >
                      Supprimer
                    </Button>
                  </div>
                </AdminTableRow>
              ))}
            </AdminTable>
          )}
        </>
      )}

      {confirming ? (
        <ConfirmDialog
          open
          title={`Supprimer « ${confirming.label} » ?`}
          description={
            confirming.kind === 'institutions'
              ? 'Le backend refusera si des formations y sont encore rattachées.'
              : 'Cette suppression est définitive.'
          }
          confirmLabel="Supprimer"
          cancelLabel="Annuler"
          onCancel={() => setConfirming(null)}
          onConfirm={() => {
            const target = confirming;
            setConfirming(null);
            void run(async () => {
              if (target.kind === 'institutions') {
                await deleteInstitution(target.id);
                await loadInstitutions(countryFilter);
              } else {
                await deleteProgram(target.id);
                await loadPrograms(institutionFilter);
              }
            }, 'Supprimé.');
          }}
        />
      ) : null}
    </DashboardShell>
  );
}
