import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import {
  AdminCapability,
  getAdminCapabilities,
  hasAdminCapability,
  InternalRole,
  isInternalRole,
} from './admin-capabilities';

describe('admin capability presentation matrix', () => {
  it.each(Object.values(InternalRole))('recognizes the %s role', (role) => {
    expect(isInternalRole(role)).toBe(true);
  });

  it('fails closed for missing and unknown roles', () => {
    expect(isInternalRole('advisor')).toBe(false);
    expect(getAdminCapabilities('advisor')).toEqual([]);
    expect(
      hasAdminCapability('advisor', AdminCapability.ViewScholarshipContent),
    ).toBe(false);
    expect(
      hasAdminCapability(null, AdminCapability.ViewScholarshipContent),
    ).toBe(false);
  });

  it('limits outcome verification to moderators and administrators', () => {
    const allowed = Object.values(InternalRole).filter((role) =>
      hasAdminCapability(role, AdminCapability.VerifyOutcomes),
    );

    expect(allowed).toEqual([
      InternalRole.Moderator,
      InternalRole.Admin,
      InternalRole.SuperAdmin,
    ]);
  });

  it('keeps global AI controls super-admin-only', () => {
    for (const capability of [
      AdminCapability.ManageAiBudget,
      AdminCapability.ManageAiPrompt,
      AdminCapability.ManageFeatureFlags,
    ]) {
      const allowed = Object.values(InternalRole).filter((role) =>
        hasAdminCapability(role, capability),
      );
      expect(allowed).toEqual([InternalRole.SuperAdmin]);
    }
  });

  it('distinguishes assigned review access from commercial metadata access', () => {
    expect(
      hasAdminCapability(
        InternalRole.Counselor,
        AdminCapability.ViewAssignedReviewRequests,
      ),
    ).toBe(true);
    expect(
      hasAdminCapability(
        InternalRole.Commercial,
        AdminCapability.ViewReviewRequestMetadata,
      ),
    ).toBe(true);
    expect(
      hasAdminCapability(
        InternalRole.Commercial,
        AdminCapability.ViewAssignedReviewRequests,
      ),
    ).toBe(false);
    expect(
      hasAdminCapability(
        InternalRole.Commercial,
        AdminCapability.ViewSharedReviewDocuments,
      ),
    ).toBe(false);
  });

  it('separates counselor self-service from administrator assignment controls', () => {
    expect(
      hasAdminCapability(
        InternalRole.Counselor,
        AdminCapability.TriageReviewRequests,
      ),
    ).toBe(true);
    expect(
      hasAdminCapability(
        InternalRole.Counselor,
        AdminCapability.ManageOwnAvailability,
      ),
    ).toBe(true);
    expect(
      hasAdminCapability(
        InternalRole.Counselor,
        AdminCapability.AssignReviewRequests,
      ),
    ).toBe(false);
    expect(
      hasAdminCapability(
        InternalRole.Admin,
        AdminCapability.ManageCounsellorAvailability,
      ),
    ).toBe(true);
  });

  it('grants the interest list to the four roles that call prospects', () => {
    const allowed = Object.values(InternalRole).filter((role) =>
      hasAdminCapability(role, AdminCapability.ViewInterestList),
    );

    // Exactement le `@Roles` de classe d'AdminEefInterestController. Les deux
    // côtés doivent dire la même chose : le menu du back-office proposait cette
    // page à `moderator` et `content_manager`, que le contrôleur refuse — un
    // menu qui invite vers une porte fermée apprend à ignorer les erreurs.
    expect(allowed.sort()).toEqual(
      [
        InternalRole.Admin,
        InternalRole.SuperAdmin,
        InternalRole.Commercial,
        InternalRole.Counselor,
      ].sort(),
    );
  });

  it('keeps the personal-data export strictly narrower than the interest list', () => {
    // Formulé comme une RELATION et non comme deux listes : si demain on élargit
    // la lecture, cette assertion continue de dire ce qui compte — faire sortir
    // la table dans un fichier n'est pas le même acte que lire une page.
    const canView = Object.values(InternalRole).filter((r) =>
      hasAdminCapability(r, AdminCapability.ViewInterestList),
    );
    const canExport = Object.values(InternalRole).filter((r) =>
      hasAdminCapability(r, AdminCapability.ExportPersonalData),
    );

    expect(canExport.length).toBeLessThan(canView.length);
    for (const role of canExport) {
      expect(canView).toContain(role);
    }
  });

  it('requires an administrator role before showing personal-data export', () => {
    const allowed = Object.values(InternalRole).filter((role) =>
      hasAdminCapability(role, AdminCapability.ExportPersonalData),
    );

    expect(allowed).toEqual([
      InternalRole.Admin,
      InternalRole.SuperAdmin,
    ]);
  });

  it('separates partnership, pilot recruitment, and impact governance', () => {
    expect(
      hasAdminCapability(
        InternalRole.Commercial,
        AdminCapability.ManagePartnerAgreements,
      ),
    ).toBe(true);
    expect(
      hasAdminCapability(
        InternalRole.Commercial,
        AdminCapability.RecruitPilotParticipants,
      ),
    ).toBe(true);
    expect(
      hasAdminCapability(
        InternalRole.Commercial,
        AdminCapability.ManagePilots,
      ),
    ).toBe(false);
    expect(
      hasAdminCapability(
        InternalRole.Moderator,
        AdminCapability.ViewPilotAggregates,
      ),
    ).toBe(true);
    expect(
      hasAdminCapability(
        InternalRole.Moderator,
        AdminCapability.FreezeImpactSnapshots,
      ),
    ).toBe(false);
    expect(
      hasAdminCapability(
        InternalRole.Admin,
        AdminCapability.FreezeImpactSnapshots,
      ),
    ).toBe(true);
  });

  it('returns frozen capability collections', () => {
    expect(Object.isFrozen(getAdminCapabilities(InternalRole.Counselor))).toBe(
      true,
    );
    expect(Object.isFrozen(getAdminCapabilities('unknown'))).toBe(true);
  });
});

describe('ManageCatalogContent — miroir du contrôleur backend', () => {
  // `AdminCatalogController` porte @Roles(Admin, SuperAdmin, ContentManager).
  // La navigation masque l'entrée Catalogue sur cette capacité : si les deux
  // listes divergent, soit un rôle voit une porte fermée, soit un rôle habilité
  // perd l'accès sans que rien ne le signale.
  it.each([
    InternalRole.Admin,
    InternalRole.SuperAdmin,
    InternalRole.ContentManager,
  ])('%s peut gérer le catalogue', (role) => {
    expect(hasAdminCapability(role, AdminCapability.ManageCatalogContent)).toBe(
      true,
    );
  });

  it.each([
    InternalRole.Counselor,
    InternalRole.Commercial,
    InternalRole.Moderator,
  ])('%s ne le peut pas', (role) => {
    expect(hasAdminCapability(role, AdminCapability.ManageCatalogContent)).toBe(
      false,
    );
  });

  // Les deux capacités couvrent des contrôleurs différents — bourses d'un côté,
  // catalogue d'écoles de l'autre. Les confondre ferait dériver l'une quand
  // l'autre change de périmètre.
  it('reste distincte de ManageScholarshipContent', () => {
    expect(AdminCapability.ManageCatalogContent).not.toBe(
      AdminCapability.ManageScholarshipContent,
    );
  });

  it('un rôle inconnu n’a aucun accès', () => {
    expect(
      hasAdminCapability('stagiaire', AdminCapability.ManageCatalogContent),
    ).toBe(false);
    expect(
      hasAdminCapability(null, AdminCapability.ManageCatalogContent),
    ).toBe(false);
  });
});

describe('PublishEefCatalog — miroir du contrôleur backend', () => {
  // `EefPublicationController` porte @Roles(Admin, SuperAdmin) : PAS ContentManager,
  // qui édite le catalogue sans signer sa publication. La navigation masque
  // l'entrée sur cette capacité ; si les deux listes divergent, un rôle voit une
  // porte fermée, ou un rôle habilité perd l'accès sans le savoir.
  it.each([InternalRole.Admin, InternalRole.SuperAdmin])(
    '%s peut publier l’import',
    (role) => {
      expect(hasAdminCapability(role, AdminCapability.PublishEefCatalog)).toBe(true);
    },
  );

  it.each([
    InternalRole.ContentManager,
    InternalRole.Moderator,
    InternalRole.Commercial,
    InternalRole.Counselor,
  ])('%s ne le peut pas', (role) => {
    expect(hasAdminCapability(role, AdminCapability.PublishEefCatalog)).toBe(false);
  });

  it('reste distincte de ManageCatalogContent, que ContentManager possède', () => {
    expect(AdminCapability.PublishEefCatalog).not.toBe(
      AdminCapability.ManageCatalogContent,
    );
    expect(
      hasAdminCapability(InternalRole.ContentManager, AdminCapability.ManageCatalogContent),
    ).toBe(true);
  });

  it('un rôle inconnu n’a aucun accès', () => {
    expect(hasAdminCapability('stagiaire', AdminCapability.PublishEefCatalog)).toBe(false);
    expect(hasAdminCapability(null, AdminCapability.PublishEefCatalog)).toBe(false);
  });
});

describe('SendLargeScholarshipOpening — miroir de OPENING_SEND_ROLES', () => {
  // `activate` refuse (403 OPENING_REQUIRES_ADMIN) une annonce au-delà du seuil
  // à tout rôle hors `OPENING_SEND_ROLES`. Le panneau d'ouverture désactive son
  // bouton sur cette capacité : si les deux listes divergent, un rôle se voit
  // proposer un envoi que le serveur refusera, ou un administrateur perd le
  // bouton sans raison.
  it.each([InternalRole.Admin, InternalRole.SuperAdmin])(
    '%s peut annoncer au-delà du seuil',
    (role) => {
      expect(
        hasAdminCapability(role, AdminCapability.SendLargeScholarshipOpening),
      ).toBe(true);
    },
  );

  it.each([
    InternalRole.ContentManager,
    InternalRole.Moderator,
    InternalRole.Commercial,
    InternalRole.Counselor,
  ])('%s ne le peut pas', (role) => {
    expect(
      hasAdminCapability(role, AdminCapability.SendLargeScholarshipOpening),
    ).toBe(false);
  });

  it('accorde exactement les rôles du contrat backend', () => {
    const contract = readFileSync(
      join(
        __dirname,
        '..',
        '..',
        'backend',
        'src',
        'modules',
        'scholarships-index',
        'opening',
        'scholarship-opening.contract.ts',
      ),
      'utf8',
    );
    const block =
      /export const OPENING_SEND_ROLES[^=]*=\s*\[([^\]]*)\]/.exec(contract)?.[1] ??
      '';
    const backendRoles = [...block.matchAll(/InternalRole\.(\w+)/g)].map(
      ([, name]) => InternalRole[name as keyof typeof InternalRole],
    );
    expect(backendRoles.length).toBeGreaterThan(0);

    const allowed = Object.values(InternalRole).filter((role) =>
      hasAdminCapability(role, AdminCapability.SendLargeScholarshipOpening),
    );
    expect(allowed.sort()).toEqual(backendRoles.sort());
  });

  it('un rôle inconnu n’a aucun accès', () => {
    expect(
      hasAdminCapability('stagiaire', AdminCapability.SendLargeScholarshipOpening),
    ).toBe(false);
    expect(
      hasAdminCapability(null, AdminCapability.SendLargeScholarshipOpening),
    ).toBe(false);
  });
});
