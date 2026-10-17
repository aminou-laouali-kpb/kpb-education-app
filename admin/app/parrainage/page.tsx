import { Suspense } from 'react';

import { CampaignsHub } from '../../components/referral-campaigns/campaigns-hub';

/** Compétition ambassadeurs : campagnes, classement, participants, prix. */
export default function ParrainagePage() {
  return (
    <Suspense fallback={<div aria-busy="true">Chargement…</div>}>
      <CampaignsHub />
    </Suspense>
  );
}
