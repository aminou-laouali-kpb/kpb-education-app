import { Suspense } from 'react';

import { CommunityHub } from '../../components/community/community-hub';

/** Communauté : file de modération, contenus, membres, réglages, statistiques. */
export default function CommunityPage() {
  return (
    <Suspense fallback={<div aria-busy="true">Chargement…</div>}>
      <CommunityHub />
    </Suspense>
  );
}
