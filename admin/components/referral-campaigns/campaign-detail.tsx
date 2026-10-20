'use client';

import { useCallback, useEffect, useState } from 'react';

import {
  type AmbassadorRow,
  ambassadorsApi,
  availableActions,
  type Campaign,
  type CampaignAction,
  type CampaignFormInput,
  type CampaignReferralRow,
  campaignsApi,
  buildCampaignPayload,
  canForfeit,
  editableFields,
  formatFcfa,
  inviteUrl,
  isPrizeHolderChanged,
  type Leaderboard,
  type LeaderboardItem,
  type PrizeAward,
  type PrizeForfeit,
  prizeAmountsText,
  publicLeaderboardUrl,
  REFERRAL_VARIANT,
  STATUS_VARIANT,
} from '../../lib/referral-campaigns';
import { useLocale } from '../locale-provider';
import {
  AdminTable,
  AdminTableRow,
  Alert,
  Badge,
  Button,
  CellText,
  EmptyState,
  Field,
  Input,
  Modal,
  Select,
  Textarea,
} from '../ui';
import { CampaignFields } from './campaigns-hub';

type Tab = 'leaderboard' | 'enroll' | 'prizes' | 'settings';

function errorText(e: unknown, fallback: string): string {
  return e instanceof Error ? e.message : fallback;
}

function download(text: string, filename: string) {
  const blob = new Blob([text], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

/** Une campagne : en-tête (statut, actions), puis classement, inscriptions, prix, paramètres. */
export function CampaignDetail({
  campaignId,
  canManage,
  onChanged,
}: Readonly<{ campaignId: string; canManage: boolean; onChanged: () => void }>) {
  const { t, locale } = useLocale();
  const [board, setBoard] = useState<Leaderboard | null>(null);
  const [filters, setFilters] = useState<{ city: string; country: string }>({ city: '', country: '' });
  const [tab, setTab] = useState<Tab>('leaderboard');
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [selected, setSelected] = useState<LeaderboardItem | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      setBoard(await campaignsApi.leaderboard(campaignId, filters));
    } catch (e) {
      setError(errorText(e, t('parrainage.loadError')));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [campaignId, filters.city, filters.country]);

  useEffect(() => {
    void load();
  }, [load]);

  async function run(label: string, fn: () => Promise<unknown>, success?: string) {
    setBusy(label);
    setError(null);
    setNotice(null);
    try {
      await fn();
      if (success) setNotice(success);
      await load();
      onChanged();
    } catch (e) {
      setError(errorText(e, t('parrainage.saveError')));
    } finally {
      setBusy(null);
    }
  }

  function transition(action: CampaignAction) {
    if (!window.confirm(t(`parrainage.confirm.${action}`))) return;
    void run(action, () => campaignsApi.transition(campaignId, action), t('parrainage.done'));
  }

  async function exportCsv(scope: 'leaderboard' | 'referrals') {
    setBusy(`export-${scope}`);
    setError(null);
    try {
      download(await campaignsApi.exportCsv(campaignId, scope), `${board?.campaign.slug ?? 'campagne'}-${scope}.csv`);
    } catch (e) {
      setError(errorText(e, t('parrainage.exportError')));
    } finally {
      setBusy(null);
    }
  }

  if (!board) {
    return error ? <Alert variant="danger">{error}</Alert> : <p style={{ margin: 0 }}>{t('parrainage.loading')}</p>;
  }
  const c = board.campaign;
  const dateFmt = (iso: string | null) =>
    iso
      ? new Intl.DateTimeFormat(locale === 'fr' ? 'fr-FR' : 'en-GB', {
          dateStyle: 'medium',
          timeStyle: 'short',
        }).format(new Date(iso))
      : '—';

  return (
    <div style={{ display: 'grid', gap: 14 }}>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      {notice ? <Alert variant="success">{notice}</Alert> : null}

      <section style={{ display: 'grid', gap: 8 }}>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
          <h2 style={{ margin: 0, fontSize: 20 }}>{locale === 'fr' ? c.nameFr : c.nameEn}</h2>
          <Badge variant={STATUS_VARIANT[c.status]}>{t(`parrainage.status.${c.status}`)}</Badge>
          {c.podiumValidatedAt ? <Badge variant="info">{t('parrainage.podiumValidated')}</Badge> : null}
        </div>
        <div style={{ color: 'var(--text-muted)', fontSize: 14 }}>
          {t('parrainage.window')
            .replace('{start}', c.startDate)
            .replace('{end}', c.endDate)
            .replace('{tz}', c.timeZone)}{' '}
          · {t('parrainage.windowUtc').replace('{start}', c.startsAt).replace('{end}', c.endsAt)}
        </div>
        <div style={{ color: 'var(--text-muted)', fontSize: 14 }}>
          {t('parrainage.lastComputed')} {dateFmt(c.lastComputedAt)} ·{' '}
          <a href={publicLeaderboardUrl(c.slug)} target="_blank" rel="noreferrer">
            {publicLeaderboardUrl(c.slug)}
          </a>
          {c.status === 'draft' ? ` (${t('parrainage.publicHiddenDraft')})` : ''}
        </div>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {canManage
            ? availableActions(c).map((action) => (
                <Button
                  key={action}
                  size="sm"
                  variant={action === 'close' || action === 'freeze' ? 'danger' : 'primary'}
                  loading={busy === action}
                  disabled={busy !== null}
                  onClick={() => transition(action)}
                >
                  {t(`parrainage.action.${action}`)}
                </Button>
              ))
            : null}
          {canManage && c.status !== 'closed' ? (
            <Button
              size="sm"
              variant="secondary"
              loading={busy === 'recompute'}
              disabled={busy !== null}
              onClick={() =>
                void run('recompute', () => campaignsApi.recompute(campaignId), t('parrainage.recomputed'))
              }
            >
              {t('parrainage.recompute')}
            </Button>
          ) : null}
          {canManage ? (
            <>
              <Button size="sm" variant="ghost" disabled={busy !== null} onClick={() => void exportCsv('leaderboard')}>
                {t('parrainage.exportLeaderboard')}
              </Button>
              <Button size="sm" variant="ghost" disabled={busy !== null} onClick={() => void exportCsv('referrals')}>
                {t('parrainage.exportReferrals')}
              </Button>
            </>
          ) : null}
        </div>
      </section>

      <nav style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }} aria-label={t('parrainage.tabs')}>
        {(['leaderboard', 'enroll', 'prizes', 'settings'] as Tab[]).map((key) => (
          <Button
            key={key}
            size="sm"
            variant={tab === key ? 'primary' : 'secondary'}
            aria-pressed={tab === key}
            onClick={() => setTab(key)}
          >
            {t(`parrainage.tab.${key}`)}
          </Button>
        ))}
      </nav>

      {tab === 'leaderboard' ? (
        <LeaderboardTab board={board} filters={filters} setFilters={setFilters} onOpen={setSelected} />
      ) : null}
      {tab === 'enroll' ? (
        <EnrollTab campaign={c} canManage={canManage} onEnrolled={() => void load()} />
      ) : null}
      {tab === 'prizes' ? <PrizesTab campaign={c} board={board} canManage={canManage} /> : null}
      {tab === 'settings' ? (
        <SettingsTab campaign={c} canManage={canManage} onSaved={() => void run('settings', async () => undefined)} />
      ) : null}

      <ParticipantModal
        campaign={c}
        participant={selected}
        canManage={canManage}
        onClose={() => setSelected(null)}
        onChanged={async () => {
          await load();
          onChanged();
        }}
      />
    </div>
  );
}

// ── Classement ───────────────────────────────────────────────────────────────

function LeaderboardTab({
  board,
  filters,
  setFilters,
  onOpen,
}: Readonly<{
  board: Leaderboard;
  filters: { city: string; country: string };
  setFilters: (f: { city: string; country: string }) => void;
  onOpen: (item: LeaderboardItem) => void;
}>) {
  const { t } = useLocale();
  return (
    <div style={{ display: 'grid', gap: 10 }}>
      <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
        <Field label={t('parrainage.filterCity')}>
          {({ id }) => (
            <Select id={id} value={filters.city} onChange={(e) => setFilters({ ...filters, city: e.target.value })}>
              <option value="">{t('parrainage.all')}</option>
              {board.cities.map((city) => (
                <option key={city} value={city}>
                  {city}
                </option>
              ))}
            </Select>
          )}
        </Field>
        <Field label={t('parrainage.filterCountry')}>
          {({ id }) => (
            <Select
              id={id}
              value={filters.country}
              onChange={(e) => setFilters({ ...filters, country: e.target.value })}
            >
              <option value="">{t('parrainage.all')}</option>
              {board.countries.map((country) => (
                <option key={country} value={country}>
                  {country}
                </option>
              ))}
            </Select>
          )}
        </Field>
      </div>
      {board.items.length === 0 ? (
        <EmptyState title={t('parrainage.noParticipantsTitle')} description={t('parrainage.noParticipantsBody')} />
      ) : (
        <AdminTable
          cols="0.4fr 1.6fr 0.6fr 0.6fr 0.6fr 0.6fr 1.3fr"
          columns={[
            t('parrainage.colRank'),
            t('parrainage.colAmbassador'),
            t('parrainage.colQualified'),
            t('parrainage.colToReview'),
            t('parrainage.colPending'),
            t('parrainage.colExcluded'),
            t('parrainage.colRankable'),
          ]}
          footnote={t('parrainage.leaderboardNote')}
        >
          {board.items.map((item) => (
            <AdminTableRow key={item.id} onSelect={() => onOpen(item)}>
              <CellText primary={item.rank ?? '—'} />
              <CellText primary={item.displayName} sub={`${item.fullName} · ${item.ambassadorCode}`} />
              <CellText primary={String(item.qualifiedCount)} />
              <CellText primary={String(item.flaggedCount)} />
              <CellText primary={String(item.pendingCount)} />
              <CellText primary={String(item.excludedCount)} />
              <div>
                {item.unrankableReason ? (
                  <Badge variant="warning">{t(`parrainage.unrankable.${item.unrankableReason}`)}</Badge>
                ) : (
                  <Badge variant="success">{t('parrainage.rankable')}</Badge>
                )}
              </div>
            </AdminTableRow>
          ))}
        </AdminTable>
      )}
    </div>
  );
}

// ── Détail d'un participant ──────────────────────────────────────────────────

function ParticipantModal({
  campaign,
  participant,
  canManage,
  onClose,
  onChanged,
}: Readonly<{
  campaign: Campaign;
  participant: LeaderboardItem | null;
  canManage: boolean;
  onClose: () => void;
  onChanged: () => Promise<void>;
}>) {
  const { t, locale } = useLocale();
  const [rows, setRows] = useState<CampaignReferralRow[]>([]);
  const [form, setForm] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const loadRows = useCallback(async () => {
    if (!participant) return;
    try {
      setRows((await campaignsApi.referrals(campaign.id, participant.id)).items ?? []);
    } catch (e) {
      setError(errorText(e, t('parrainage.loadError')));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [campaign.id, participant?.id]);

  useEffect(() => {
    setError(null);
    setRows([]);
    if (participant) {
      setForm({
        publicName: participant.publicName,
        city: participant.city,
        country: participant.country,
        status: participant.status,
        statusReason: participant.statusReason ?? '',
        minorStatus: participant.minorStatus,
        parentalAuthStatus: participant.parentalAuthStatus,
        parentalAuthNote: participant.parentalAuthNote ?? '',
      });
      void loadRows();
    }
  }, [participant, loadRows]);

  if (!participant) return null;
  const closed = campaign.status === 'closed';
  const editable = canManage && !closed;
  const fmt = (iso: string | null) =>
    iso
      ? new Intl.DateTimeFormat(locale === 'fr' ? 'fr-FR' : 'en-GB', { dateStyle: 'short', timeStyle: 'short' }).format(
          new Date(iso),
        )
      : '—';

  async function save() {
    setBusy(true);
    setError(null);
    try {
      const body: Record<string, unknown> = {
        publicName: form.publicName,
        city: form.city,
        country: form.country,
        status: form.status,
        minorStatus: form.minorStatus,
        parentalAuthStatus: form.parentalAuthStatus,
        parentalAuthNote: form.parentalAuthNote,
      };
      if (form.status !== 'active') body.statusReason = form.statusReason;
      await campaignsApi.updateParticipant(campaign.id, participant!.id, body);
      await onChanged();
      onClose();
    } catch (e) {
      setError(errorText(e, t('parrainage.saveError')));
    } finally {
      setBusy(false);
    }
  }

  async function decide(row: CampaignReferralRow, decision: 'validated' | 'excluded' | 'clear') {
    let reason: string | undefined;
    if (decision === 'excluded') {
      reason = window.prompt(t('parrainage.excludeReasonPrompt')) ?? undefined;
      if (!reason || reason.trim().length < 3) return;
    }
    if (decision === 'validated') {
      reason = window.prompt(t('parrainage.validateReasonPrompt')) ?? undefined;
    }
    setBusy(true);
    setError(null);
    try {
      await campaignsApi.decide(campaign.id, row.id, decision, reason?.trim() || undefined);
      await loadRows();
      await onChanged();
    } catch (e) {
      setError(errorText(e, t('parrainage.saveError')));
    } finally {
      setBusy(false);
    }
  }

  const select = (key: string, options: string[], prefix: string) => (
    <Field label={t(`parrainage.participant.${key}`)}>
      {({ id }) => (
        <Select
          id={id}
          value={form[key] ?? ''}
          disabled={!editable}
          onChange={(e) => setForm({ ...form, [key]: e.target.value })}
        >
          {options.map((o) => (
            <option key={o} value={o}>
              {t(`parrainage.${prefix}.${o}`)}
            </option>
          ))}
        </Select>
      )}
    </Field>
  );
  const input = (key: string) => (
    <Field label={t(`parrainage.participant.${key}`)}>
      {({ id }) => (
        <Input
          id={id}
          value={form[key] ?? ''}
          disabled={!editable}
          onChange={(e) => setForm({ ...form, [key]: e.target.value })}
        />
      )}
    </Field>
  );

  return (
    <Modal
      open
      size="lg"
      title={participant.displayName}
      onClose={onClose}
      busy={busy}
      footer={
        <>
          <Button variant="secondary" onClick={onClose} disabled={busy}>
            {t('parrainage.close')}
          </Button>
          {editable ? (
            <Button onClick={save} loading={busy}>
              {t('parrainage.save')}
            </Button>
          ) : null}
        </>
      }
    >
      <div style={{ display: 'grid', gap: 12 }}>
        {error ? <Alert variant="danger">{error}</Alert> : null}
        <div style={{ fontSize: 14, color: 'var(--text-muted)', display: 'grid', gap: 4 }}>
          <span>
            {participant.fullName} · {participant.email}
          </span>
          <span>
            {t('parrainage.participant.codes')} <strong>{participant.ambassadorCode}</strong>
            {participant.personalCode ? (
              <>
                {' '}
                · <strong>{participant.personalCode}</strong>
              </>
            ) : null}{' '}
            · {inviteUrl(participant.personalCode ?? participant.ambassadorCode)}
          </span>
        </div>
        {participant.minorStatus !== 'adult' ? (
          <Alert variant="warning">{t('parrainage.participant.minorHint')}</Alert>
        ) : null}
        <div style={{ display: 'grid', gap: 12, gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))' }}>
          {input('publicName')}
          {input('city')}
          {input('country')}
          {select('status', ['active', 'withdrawn', 'disqualified'], 'participantStatus')}
          {form.status !== 'active' ? input('statusReason') : null}
          {select('minorStatus', ['adult', 'minor', 'unknown'], 'minor')}
          {select('parentalAuthStatus', ['not_required', 'pending', 'verified', 'refused'], 'parental')}
          {input('parentalAuthNote')}
        </div>
        {participant.parentalAuthVerifiedAt ? (
          <p style={{ margin: 0, fontSize: 13, color: 'var(--text-muted)' }}>
            {t('parrainage.participant.verifiedAt')} {fmt(participant.parentalAuthVerifiedAt)}
          </p>
        ) : null}

        <h3 style={{ margin: '8px 0 0', fontSize: 16 }}>{t('parrainage.referralsTitle')}</h3>
        {rows.length === 0 ? (
          <p style={{ margin: 0 }}>{t('parrainage.noReferrals')}</p>
        ) : (
          <AdminTable
            cols="1.4fr 0.9fr 0.9fr 0.8fr 1.1fr 1.2fr"
            columns={[
              t('parrainage.colReferee'),
              t('parrainage.colAttached'),
              t('parrainage.colQualifiedAt'),
              t('parrainage.colStatus'),
              t('parrainage.colFlags'),
              t('parrainage.colActions'),
            ]}
          >
            {rows.map((row) => (
              <AdminTableRow key={row.id}>
                <CellText primary={row.refereeName || '—'} sub={row.refereeEmail} />
                <CellText primary={fmt(row.attachedAt)} />
                <CellText primary={fmt(row.qualifiedAt)} />
                <div>
                  <Badge variant={REFERRAL_VARIANT[row.status]}>{t(`parrainage.referralStatus.${row.status}`)}</Badge>
                </div>
                <CellText
                  primary={row.flags.map((f) => t(`parrainage.flag.${f}`)).join(', ') || '—'}
                  sub={row.adminDecisionReason ?? undefined}
                />
                <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                  {editable && row.adminDecision !== 'validated' && row.status === 'flagged' ? (
                    <Button size="sm" variant="success" disabled={busy} onClick={() => void decide(row, 'validated')}>
                      {t('parrainage.validate')}
                    </Button>
                  ) : null}
                  {editable && row.adminDecision !== 'excluded' ? (
                    <Button size="sm" variant="dangerOutline" disabled={busy} onClick={() => void decide(row, 'excluded')}>
                      {t('parrainage.exclude')}
                    </Button>
                  ) : null}
                  {editable && row.adminDecision ? (
                    <Button size="sm" variant="ghost" disabled={busy} onClick={() => void decide(row, 'clear')}>
                      {t('parrainage.clearDecision')}
                    </Button>
                  ) : null}
                </div>
              </AdminTableRow>
            ))}
          </AdminTable>
        )}
      </div>
    </Modal>
  );
}

// ── Inscriptions et ambassadeurs ────────────────────────────────────────────

function EnrollTab({
  campaign,
  canManage,
  onEnrolled,
}: Readonly<{ campaign: Campaign; canManage: boolean; onEnrolled: () => void }>) {
  const { t } = useLocale();
  const [search, setSearch] = useState('');
  const [items, setItems] = useState<AmbassadorRow[]>([]);
  const [activation, setActivation] = useState({ email: '', city: '', displayName: '' });
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const closedForEnroll = campaign.status === 'frozen' || campaign.status === 'closed';

  const load = useCallback(async () => {
    try {
      setItems((await ambassadorsApi.list(search.trim() || undefined)).items ?? []);
    } catch (e) {
      setError(errorText(e, t('parrainage.loadError')));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search]);

  useEffect(() => {
    void load();
  }, [load]);

  async function act(fn: () => Promise<unknown>, success: string) {
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      await fn();
      setNotice(success);
      await load();
      onEnrolled();
    } catch (e) {
      setError(errorText(e, t('parrainage.saveError')));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div style={{ display: 'grid', gap: 14 }}>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      {notice ? <Alert variant="success">{notice}</Alert> : null}
      {canManage ? (
        <section style={{ display: 'grid', gap: 8 }}>
          <h3 style={{ margin: 0, fontSize: 16 }}>{t('parrainage.activateTitle')}</h3>
          <p style={{ margin: 0, fontSize: 14, color: 'var(--text-muted)' }}>{t('parrainage.activateHint')}</p>
          <div style={{ display: 'grid', gap: 10, gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))' }}>
            {(['email', 'city', 'displayName'] as const).map((key) => (
              <Field key={key} label={t(`parrainage.activate.${key}`)}>
                {({ id }) => (
                  <Input
                    id={id}
                    type={key === 'email' ? 'email' : 'text'}
                    value={activation[key]}
                    onChange={(e) => setActivation({ ...activation, [key]: e.target.value })}
                  />
                )}
              </Field>
            ))}
          </div>
          <div>
            <Button
              disabled={busy || !activation.email.trim() || !activation.city.trim()}
              onClick={() =>
                void act(
                  () =>
                    ambassadorsApi.activate({
                      email: activation.email.trim(),
                      city: activation.city.trim(),
                      ...(activation.displayName.trim() ? { displayName: activation.displayName.trim() } : {}),
                    }),
                  t('parrainage.activated'),
                )
              }
            >
              {t('parrainage.activateSubmit')}
            </Button>
          </div>
        </section>
      ) : null}

      <section style={{ display: 'grid', gap: 8 }}>
        <h3 style={{ margin: 0, fontSize: 16 }}>{t('parrainage.ambassadorsTitle')}</h3>
        <Field label={t('parrainage.search')}>
          {({ id }) => <Input id={id} value={search} onChange={(e) => setSearch(e.target.value)} />}
        </Field>
        {items.length === 0 ? (
          <p style={{ margin: 0 }}>{t('parrainage.noAmbassadors')}</p>
        ) : (
          <AdminTable
            cols="1.4fr 1fr 0.8fr 0.8fr 1.4fr"
            columns={[
              t('parrainage.colAmbassador'),
              t('parrainage.colCodes'),
              t('parrainage.colCity'),
              t('parrainage.colApproved'),
              t('parrainage.colActions'),
            ]}
          >
            {items.map((a) => (
              <AdminTableRow key={a.id}>
                <CellText primary={a.fullName || a.displayName} sub={a.email} />
                <CellText primary={a.code} sub={a.personalCode ?? undefined} />
                <CellText primary={a.city || '—'} sub={t(`parrainage.minor.${a.minorStatus}`)} />
                <div>
                  {a.approvedAt ? (
                    <Badge variant="success">{t('parrainage.approvedYes')}</Badge>
                  ) : (
                    <Badge variant="neutral">{t('parrainage.approvedNo')}</Badge>
                  )}
                </div>
                <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                  {canManage && a.approvedAt && !closedForEnroll ? (
                    <Button
                      size="sm"
                      disabled={busy}
                      onClick={() =>
                        void act(() => campaignsApi.enroll(campaign.id, { ambassadorId: a.id }), t('parrainage.enrolled'))
                      }
                    >
                      {t('parrainage.enroll')}
                    </Button>
                  ) : null}
                  {canManage && a.approvedAt ? (
                    <Button
                      size="sm"
                      variant="dangerOutline"
                      disabled={busy}
                      onClick={() => {
                        const reason = window.prompt(t('parrainage.revokeReasonPrompt'));
                        if (!reason || reason.trim().length < 3) return;
                        void act(() => ambassadorsApi.revoke(a.id, reason.trim()), t('parrainage.revoked'));
                      }}
                    >
                      {t('parrainage.revoke')}
                    </Button>
                  ) : null}
                </div>
              </AdminTableRow>
            ))}
          </AdminTable>
        )}
      </section>
    </div>
  );
}

// ── Prix et versements ──────────────────────────────────────────────────────

function PrizesTab({
  campaign,
  board,
  canManage,
}: Readonly<{ campaign: Campaign; board: Leaderboard; canManage: boolean }>) {
  const { t, locale } = useLocale();
  const [awards, setAwards] = useState<PrizeAward[]>([]);
  const [payout, setPayout] = useState<PayoutDraft | null>(null);
  const [forfeits, setForfeits] = useState<PrizeForfeit[]>([]);
  const [forfeit, setForfeit] = useState<{ award: PrizeAward; reason: string } | null>(null);
  const [error, setError] = useState<string | null>(null);
  // Le refus d'un versement ou d'un forfait s'affiche DANS la modale ouverte
  // (audit 57, F21) : l'alerte de l'onglet est derrière l'overlay, inerte.
  const [modalError, setModalError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      const res = await campaignsApi.prizes(campaign.id);
      setAwards(res.items ?? []);
      setForfeits(res.forfeits ?? []);
    } catch (e) {
      setError(errorText(e, t('parrainage.loadError')));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [campaign.id]);

  useEffect(() => {
    void load();
  }, [load, campaign.podiumValidatedAt]);

  function openPayout(next: PayoutDraft | null) {
    setModalError(null);
    setPayout(next);
  }

  function openForfeit(next: ForfeitDraft | null) {
    setModalError(null);
    setForfeit(next);
  }

  /** Erreur dans la modale ; le lauréat a changé ⇒ la liste est rechargée. */
  async function failInModal(e: unknown) {
    setModalError(errorText(e, t('parrainage.saveError')));
    if (isPrizeHolderChanged(e)) await load();
  }

  async function savePayout() {
    if (!payout) return;
    setBusy(true);
    setModalError(null);
    try {
      await campaignsApi.payout(campaign.id, payout.rank, {
        payoutReference: payout.reference.trim(),
        recipient: payout.recipient,
        ...(payout.date ? { paidAt: new Date(`${payout.date}T12:00:00Z`).toISOString() } : {}),
      });
      setPayout(null);
      await load();
    } catch (e) {
      await failInModal(e);
    } finally {
      setBusy(false);
    }
  }

  /** « Déclarer le prix forfait et réattribuer » (correctifs 57). */
  async function saveForfeit() {
    if (!forfeit?.award.participantId) return;
    setBusy(true);
    setModalError(null);
    try {
      const res = await campaignsApi.forfeit(campaign.id, forfeit.award.rank, {
        participantId: forfeit.award.participantId,
        reason: forfeit.reason.trim(),
      });
      setAwards(res.items ?? []);
      setForfeits(res.forfeits ?? []);
      setForfeit(null);
    } catch (e) {
      await failInModal(e);
    } finally {
      setBusy(false);
    }
  }

  const preview = board.items.filter((i) => i.rank !== null).slice(0, campaign.prizes.length);
  return (
    <div style={{ display: 'grid', gap: 12 }}>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <p style={{ margin: 0 }}>
        {t('parrainage.prizesConfigured')}{' '}
        {campaign.prizes.map((p) => `${p.rank}. ${formatFcfa(p.amountFcfa, locale)}`).join(' · ') || '—'}
      </p>
      {!campaign.podiumValidatedAt ? (
        <>
          <Alert variant="info">{t('parrainage.podiumNotValidated')}</Alert>
          {preview.length ? (
            <ul style={{ margin: 0 }}>
              {preview.map((p) => (
                <li key={p.id}>
                  {p.rank}. {p.displayName} — {p.qualifiedCount}
                </li>
              ))}
            </ul>
          ) : null}
        </>
      ) : awards.length === 0 ? (
        <p style={{ margin: 0 }}>{t('parrainage.noAwards')}</p>
      ) : (
        <AdminTable
          cols="0.4fr 1.4fr 0.8fr 0.8fr 0.8fr 1.2fr"
          columns={[
            t('parrainage.colRank'),
            t('parrainage.colAmbassador'),
            t('parrainage.colAmount'),
            t('parrainage.colRecipient'),
            t('parrainage.colPayout'),
            t('parrainage.colActions'),
          ]}
        >
          {awards.map((a) => (
            <AdminTableRow key={a.id}>
              <CellText primary={a.rank} />
              <CellText primary={a.publicNameSnapshot} />
              <CellText primary={formatFcfa(a.amountFcfa, locale)} />
              <CellText primary={t(`parrainage.recipient.${a.recipient}`)} />
              <CellText
                primary={a.payoutStatus === 'paid' ? t('parrainage.paid') : t('parrainage.unpaid')}
                sub={a.payoutReference ? `${a.payoutMethod} · ${a.payoutReference} · ${a.paidAt?.slice(0, 10)}` : undefined}
              />
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                {canManage && a.payoutStatus !== 'paid' ? (
                  <Button
                    size="sm"
                    onClick={() =>
                      openPayout({ rank: a.rank, reference: '', date: new Date().toISOString().slice(0, 10), recipient: a.recipient })
                    }
                  >
                    {t('parrainage.recordPayout')}
                  </Button>
                ) : null}
                {canManage && canForfeit(a) ? (
                  <Button size="sm" variant="dangerOutline" onClick={() => openForfeit({ award: a, reason: '' })}>
                    {t('parrainage.forfeit')}
                  </Button>
                ) : null}
              </div>
            </AdminTableRow>
          ))}
        </AdminTable>
      )}
      {forfeits.length > 0 ? (
        <div style={{ display: 'grid', gap: 4 }}>
          <strong>{t('parrainage.forfeitsTitle')}</strong>
          <ul style={{ margin: 0 }}>
            {forfeits.map((f) => (
              <li key={f.id}>
                {f.rank}. {f.publicNameSnapshot} — {formatFcfa(f.amountFcfa, locale)} · {f.forfeitedAt.slice(0, 10)} ·{' '}
                {f.reason} ·{' '}
                {f.replacedByParticipantId ? t('parrainage.forfeitReassigned') : t('parrainage.forfeitVacant')}
              </li>
            ))}
          </ul>
        </div>
      ) : null}
      <Modal
        open={forfeit !== null}
        title={t('parrainage.forfeit')}
        onClose={() => openForfeit(null)}
        busy={busy}
        footer={
          <>
            <Button variant="secondary" onClick={() => openForfeit(null)} disabled={busy}>
              {t('parrainage.cancel')}
            </Button>
            <Button
              variant="danger"
              onClick={saveForfeit}
              loading={busy}
              disabled={!forfeit || forfeit.reason.trim().length < 3}
            >
              {t('parrainage.forfeitConfirm')}
            </Button>
          </>
        }
      >
        {forfeit ? <ForfeitFormBody draft={forfeit} error={modalError} onChange={setForfeit} /> : null}
      </Modal>
      <Modal
        open={payout !== null}
        title={t('parrainage.recordPayout')}
        onClose={() => openPayout(null)}
        busy={busy}
        footer={
          <>
            <Button variant="secondary" onClick={() => openPayout(null)} disabled={busy}>
              {t('parrainage.cancel')}
            </Button>
            <Button onClick={savePayout} loading={busy} disabled={!payout || payout.reference.trim().length < 2}>
              {t('parrainage.save')}
            </Button>
          </>
        }
      >
        {payout ? <PayoutFormBody draft={payout} error={modalError} onChange={setPayout} /> : null}
      </Modal>
    </div>
  );
}

type PayoutDraft = { rank: number; reference: string; date: string; recipient: string };
type ForfeitDraft = { award: PrizeAward; reason: string };

/** Contenu de la modale « Noter le versement » : l'erreur du serveur en tête. */
export function PayoutFormBody({
  draft,
  error,
  onChange,
}: Readonly<{ draft: PayoutDraft; error: string | null; onChange: (next: PayoutDraft) => void }>) {
  const { t } = useLocale();
  return (
    <div style={{ display: 'grid', gap: 10 }}>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <Alert variant="info">{t('parrainage.payoutHint')}</Alert>
      <Field label={t('parrainage.payoutReference')}>
        {({ id }) => (
          <Input id={id} value={draft.reference} onChange={(e) => onChange({ ...draft, reference: e.target.value })} />
        )}
      </Field>
      <Field label={t('parrainage.payoutDate')}>
        {({ id }) => (
          <Input id={id} type="date" value={draft.date} onChange={(e) => onChange({ ...draft, date: e.target.value })} />
        )}
      </Field>
      <Field label={t('parrainage.colRecipient')}>
        {({ id }) => (
          <Select id={id} value={draft.recipient} onChange={(e) => onChange({ ...draft, recipient: e.target.value })}>
            <option value="ambassador">{t('parrainage.recipient.ambassador')}</option>
            <option value="parent">{t('parrainage.recipient.parent')}</option>
          </Select>
        )}
      </Field>
    </div>
  );
}

/** Contenu de la modale « Déclarer le prix forfait » : l'erreur du serveur en tête. */
export function ForfeitFormBody({
  draft,
  error,
  onChange,
}: Readonly<{ draft: ForfeitDraft; error: string | null; onChange: (next: ForfeitDraft) => void }>) {
  const { t } = useLocale();
  return (
    <div style={{ display: 'grid', gap: 10 }}>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <Alert variant="warning">
        {t('parrainage.forfeitHint')
          .replace('{rank}', String(draft.award.rank))
          .replace('{name}', draft.award.publicNameSnapshot)}
      </Alert>
      <Field label={t('parrainage.forfeitReason')}>
        {({ id }) => (
          <Textarea
            id={id}
            value={draft.reason}
            placeholder={t('parrainage.forfeitReasonPlaceholder')}
            onChange={(e) => onChange({ ...draft, reason: e.target.value })}
          />
        )}
      </Field>
    </div>
  );
}

// ── Paramètres ───────────────────────────────────────────────────────────────

function SettingsTab({
  campaign,
  canManage,
  onSaved,
}: Readonly<{ campaign: Campaign; canManage: boolean; onSaved: () => void }>) {
  const { t } = useLocale();
  const initial: CampaignFormInput = {
    slug: campaign.slug,
    nameFr: campaign.nameFr,
    nameEn: campaign.nameEn,
    startDate: campaign.startDate,
    endDate: campaign.endDate,
    timeZone: campaign.timeZone,
    prizesText: prizeAmountsText(campaign.prizes),
    rulesText: campaign.rulesText ?? '',
    rulesUrl: campaign.rulesUrl ?? '',
    citiesText: campaign.eligibleCities.join(', '),
    countriesText: campaign.eligibleCountries.join(', '),
  };
  const [form, setForm] = useState<CampaignFormInput>(initial);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const editable = canManage ? editableFields(campaign.status) : [];
  const set = (key: keyof CampaignFormInput) => (value: string) => setForm((f) => ({ ...f, [key]: value }));

  async function save() {
    const built = buildCampaignPayload(form);
    if (!built.ok) {
      setErrors(built.errors);
      return;
    }
    setErrors({});
    const body: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(built.body)) {
      if (editable.includes(key)) body[key] = value;
    }
    if (editable.includes('rulesUrl')) body.rulesUrl = form.rulesUrl.trim();
    if (editable.includes('rulesText')) body.rulesText = form.rulesText;
    setBusy(true);
    setError(null);
    try {
      await campaignsApi.update(campaign.id, body);
      onSaved();
    } catch (e) {
      setError(errorText(e, t('parrainage.saveError')));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div style={{ display: 'grid', gap: 12 }}>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      {campaign.status !== 'draft' ? <Alert variant="info">{t('parrainage.settingsLocked')}</Alert> : null}
      <CampaignFields
        form={form}
        set={set}
        err={(key) => (errors[key] ? t(`parrainage.form.${errors[key]}`) : undefined)}
        editable={editable}
      />
      {editable.length ? (
        <div>
          <Button onClick={save} loading={busy}>
            {t('parrainage.save')}
          </Button>
        </div>
      ) : null}
    </div>
  );
}
