import { ModuleRef } from "@nestjs/core";
import { ForbiddenException, NotFoundException } from "@nestjs/common";

import { InternalRole } from "../../common/enums/internal-role.enum";
import { PushSenderService } from "../notifications/push-sender.service";
import { PrismaService } from "../prisma/prisma.service";
import { CaseLeadMailService } from "./case-lead-mail.service";
import { CasesService } from "./cases.service";

/**
 * Audit 2026-11-22, constat 2 : une réaffectation manuelle (assign ou PATCH)
 * doit déplacer le lien `counsellorId`. Sinon l'ancien conseiller garde la
 * portée, la messagerie, les pièces, et reçoit les alertes e-mail.
 */

type Counsellor = {
  id: string;
  fullName: string;
  email: string;
  isActive: boolean;
  adminUserId: string | null;
  adminFullName: string | null;
  createdAt: Date;
};

const JOJO: Counsellor = {
  id: "c-jojo",
  fullName: "Jojo Mensah",
  email: "jojo@kpb.test",
  isActive: true,
  adminUserId: "admin-jojo",
  adminFullName: "Jojo Mensah",
  createdAt: new Date("2026-01-01"),
};
const AWA: Counsellor = {
  id: "c-awa",
  fullName: "Awa Koné",
  email: "awa@kpb.test",
  isActive: true,
  adminUserId: "admin-awa",
  // Compte admin sous un autre libellé que la fiche conseiller.
  adminFullName: "Awa K. (KPB)",
  createdAt: new Date("2026-01-02"),
};

const jojoActor = {
  id: "admin-jojo",
  role: InternalRole.Counselor,
  fullName: "Jojo Mensah",
};
const awaActor = {
  id: "admin-awa",
  role: InternalRole.Counselor,
  fullName: "Awa K. (KPB)",
};

function makeWorld(
  counsellors: Counsellor[] = [JOJO, AWA],
  initial: Record<string, any> = {},
) {
  const row: Record<string, any> = {
    id: "case-1",
    userId: "student-1",
    referenceCode: "KPB-2026-001",
    title: "Bourse",
    status: "counselor_assigned",
    assignedAdvisorName: "Jojo Mensah",
    counsellorId: JOJO.id,
    user: { fullName: "Élève Test", email: "eleve@test.dev" },
    ...initial,
  };
  const mails: any[] = [];
  const counsellorView = () => {
    const c = counsellors.find((x) => x.id === row.counsellorId);
    return c
      ? { adminUserId: c.adminUserId, email: c.email, isActive: c.isActive }
      : null;
  };
  const view = () => ({ ...row, counsellor: counsellorView() });
  const ieq = (a: string | null, rule?: { equals: string }) =>
    !!rule && !!a && a.toLowerCase() === rule.equals.toLowerCase();
  // Évalue `counselorCaseScope` (OR profil lié / nom d'affectation).
  const inScope = (where: any) =>
    !where.OR ||
    where.OR.some(
      (clause: any) =>
        (clause.counsellor &&
          counsellorView()?.adminUserId === clause.counsellor.adminUserId) ||
        (clause.assignedAdvisorName &&
          ieq(row.assignedAdvisorName, clause.assignedAdvisorName)),
    );
  const tx = {
    case: {
      update: async ({ data }: any) => {
        Object.assign(row, data);
        return view();
      },
      findUnique: async () => view(),
    },
    caseTimelineEvent: { create: async () => ({}) },
    counsellor: {
      findMany: async ({ where }: any) =>
        counsellors
          .filter((c) =>
            where.OR.some(
              (clause: any) =>
                ieq(c.fullName, clause.fullName) ||
                ieq(c.adminFullName, clause.adminUser?.fullName),
            ),
          )
          .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime())
          .map((c) => ({ id: c.id, isActive: c.isActive })),
      findUnique: async ({ where }: any) => {
        const c = counsellors.find((x) => x.id === where.id);
        return c
          ? {
              fullName: c.fullName,
              adminUser: c.adminFullName ? { fullName: c.adminFullName } : null,
            }
          : null;
      },
    },
  };
  const client = {
    case: {
      findUnique: async () => view(),
      findFirst: async ({ where }: any) =>
        where.id === row.id && inScope(where) ? view() : null,
    },
    caseDocument: {
      findFirst: async () => ({
        id: "doc-1",
        title: "Passeport",
        fileUrl: "storage://2026-11-22/passeport.pdf",
        case: {
          assignedAdvisorName: row.assignedAdvisorName,
          counsellor: counsellorView(),
        },
      }),
    },
    caseMessage: {
      findFirst: async () => null,
      count: async () => 0,
    },
    $transaction: async (fn: (t: any) => Promise<any>) => fn(tx),
  };
  const prisma = {
    isEnabled: true,
    execute: async (fn: (p: any) => Promise<any>) => fn(client),
    tryExecute: async () => null,
  } as unknown as PrismaService;
  const leadMail = {
    notifyStudentMessage: async (record: any) => {
      mails.push(record);
    },
  } as unknown as CaseLeadMailService;
  const svc = new CasesService(
    prisma,
    {
      get: () => ({ emitCaseMessage: () => {}, emitCaseUpdated: () => {} }),
    } as unknown as ModuleRef,
    { sendToUser: async () => {} } as unknown as PushSenderService,
    leadMail,
  );
  // La projection n'est pas l'objet de ce test.
  (svc as any).mapDbCase = () => ({ id: "case-1" });
  return { svc, row, mails };
}

async function expectAccess(svc: CasesService, actor: typeof jojoActor) {
  await expect(
    svc.assertCanAccessMessaging("case-1", {
      userId: actor.id,
      role: actor.role,
      fullName: actor.fullName,
    }),
  ).resolves.toMatchObject({ id: "case-1" });
  await expect(
    svc.getInternalDocument("case-1", "doc-1", actor),
  ).resolves.toMatchObject({ id: "doc-1" });
  await expect(svc.findOneForAdmin("case-1", actor)).resolves.toMatchObject({
    id: "case-1",
  });
}

async function expectNoAccess(svc: CasesService, actor: typeof jojoActor) {
  await expect(
    svc.assertCanAccessMessaging("case-1", {
      userId: actor.id,
      role: actor.role,
      fullName: actor.fullName,
    }),
  ).rejects.toBeInstanceOf(NotFoundException);
  await expect(
    svc.getInternalDocument("case-1", "doc-1", actor),
  ).rejects.toBeInstanceOf(NotFoundException);
  await expect(svc.findOneForAdmin("case-1", actor)).rejects.toBeInstanceOf(
    NotFoundException,
  );
}

async function alertRecipient(svc: CasesService, mails: any[]) {
  await (svc as any).notifyStaffOfStudentMessage("case-1", new Date());
  return mails.at(-1)?.counsellor?.email ?? null;
}

describe("CasesService — réaffectation manuelle et lien conseiller", () => {
  it("assignCase de Jojo vers Awa : Jojo perd l'accès, Awa l'obtient et reçoit l'alerte", async () => {
    const { svc, row, mails } = makeWorld();
    await expectAccess(svc, jojoActor);
    expect(await alertRecipient(svc, mails)).toBe("jojo@kpb.test");

    // L'admin saisit le nom de la fiche, casse différente.
    await svc.assignCase("case-1", { assignedAdvisorName: "awa koné" });

    expect(row.counsellorId).toBe(AWA.id);
    await expectNoAccess(svc, jojoActor);
    // Awa passe par son profil lié, même si son compte porte un autre nom.
    await expectAccess(svc, awaActor);
    expect(await alertRecipient(svc, mails)).toBe("awa@kpb.test");
  });

  it("résout aussi par le nom du compte admin lié", async () => {
    const { svc, row } = makeWorld();
    await svc.assignCase("case-1", { assignedAdvisorName: "Awa K. (KPB)" });
    expect(row.counsellorId).toBe(AWA.id);
  });

  it("sans fiche correspondante : le lien est coupé, l'alerte part aux commerciaux", async () => {
    const { svc, row, mails } = makeWorld();
    await svc.assignCase("case-1", { assignedAdvisorName: "Fatou Externe" });

    expect(row.counsellorId).toBeNull();
    await expectNoAccess(svc, jojoActor);
    // Le nouveau conseiller garde l'accès par le nom d'affectation.
    await expectAccess(svc, {
      id: "admin-fatou",
      role: InternalRole.Counselor,
      fullName: "Fatou Externe",
    });
    await (svc as any).notifyStaffOfStudentMessage("case-1", new Date());
    expect(mails.at(-1).counsellor).toBeNull();
  });

  it("homonymes : garde la seule fiche active, sinon coupe le lien", async () => {
    const inactiveTwin = {
      ...AWA,
      id: "c-awa-old",
      isActive: false,
      adminUserId: null,
      createdAt: new Date("2025-01-01"),
    };
    const one = makeWorld([JOJO, AWA, inactiveTwin]);
    await one.svc.assignCase("case-1", { assignedAdvisorName: "Awa Koné" });
    expect(one.row.counsellorId).toBe(AWA.id);

    const activeTwin = { ...inactiveTwin, isActive: true };
    const two = makeWorld([JOJO, AWA, activeTwin]);
    await two.svc.assignCase("case-1", { assignedAdvisorName: "Awa Koné" });
    expect(two.row.counsellorId).toBeNull();
    await expectNoAccess(two.svc, jojoActor);
  });

  it("PATCH (update) avec un nouveau nom déplace aussi le lien", async () => {
    const { svc, row, mails } = makeWorld();
    await svc.update("case-1", { assignedAdvisorName: "Awa Koné" });

    expect(row.counsellorId).toBe(AWA.id);
    await expectNoAccess(svc, jojoActor);
    await expectAccess(svc, awaActor);
    expect(await alertRecipient(svc, mails)).toBe("awa@kpb.test");
  });

  it("PATCH sans nom de conseiller ne touche pas au lien", async () => {
    const { svc, row } = makeWorld();
    await svc.update("case-1", { nextStepTitle: "Pièces reçues" });
    expect(row.counsellorId).toBe(JOJO.id);
  });

  // Régression relevée en relecture : l'admin renvoie toujours le nom
  // pré-rempli (planifier un appel, prochaine étape). Ce renvoi ne doit pas
  // relancer la résolution par nom ni couper le lien existant.
  describe("même nom renvoyé => lien conservé", () => {
    // Dossier lié à Awa sous l'ancien libellé, fiche renommée depuis.
    const renamed = {
      assignedAdvisorName: "Awa Kone",
      counsellorId: AWA.id,
    };

    it("assignCase (planifier un appel) avec une fiche renommée", async () => {
      const { svc, row, mails } = makeWorld([JOJO, AWA], renamed);
      await svc.assignCase("case-1", {
        assignedAdvisorName: "Awa Kone",
        scheduledAt: "2026-12-01T10:00:00.000Z",
      });
      expect(row.counsellorId).toBe(AWA.id);
      expect(row.status).toBe("scheduled");
      await expectAccess(svc, awaActor);
      expect(await alertRecipient(svc, mails)).toBe("awa@kpb.test");
    });

    it("assignCase : espaces et casse ne comptent pas comme un changement", async () => {
      const { svc, row } = makeWorld([JOJO, AWA], renamed);
      await svc.assignCase("case-1", { assignedAdvisorName: "  awa KONE " });
      expect(row.counsellorId).toBe(AWA.id);
    });

    it("PATCH (prochaine étape) avec une fiche renommée", async () => {
      const { svc, row } = makeWorld([JOJO, AWA], renamed);
      await svc.update("case-1", {
        assignedAdvisorName: "Awa Kone",
        nextStepTitle: "Appel prévu",
      });
      expect(row.counsellorId).toBe(AWA.id);
      expect(row.nextStepTitle).toBe("Appel prévu");
      await expectAccess(svc, awaActor);
    });

    it("homonymes actifs : le lien existant est conservé (assign et PATCH)", async () => {
      const activeTwin = {
        ...AWA,
        id: "c-awa-twin",
        email: "awa.twin@kpb.test",
        adminUserId: "admin-awa-twin",
        createdAt: new Date("2025-01-01"),
      };
      const linked = { assignedAdvisorName: "Awa Koné", counsellorId: AWA.id };

      const one = makeWorld([JOJO, AWA, activeTwin], linked);
      await one.svc.assignCase("case-1", { assignedAdvisorName: "Awa Koné" });
      expect(one.row.counsellorId).toBe(AWA.id);
      expect(await alertRecipient(one.svc, one.mails)).toBe("awa@kpb.test");

      const two = makeWorld([JOJO, AWA, activeTwin], linked);
      await two.svc.update("case-1", { assignedAdvisorName: "awa koné" });
      expect(two.row.counsellorId).toBe(AWA.id);
    });

    it("un vrai changement de nom relance bien la résolution", async () => {
      const { svc, row } = makeWorld([JOJO, AWA], renamed);
      await svc.assignCase("case-1", { assignedAdvisorName: "Jojo Mensah" });
      expect(row.counsellorId).toBe(JOJO.id);
    });
  });

  // Trou relevé en revue : dossiers réaffectés AVANT le correctif (nom = Awa,
  // lien = Jojo) ou lien nul dont la fiche a été créée depuis. Le même nom
  // renvoyé doit corriger le lien quand une autre fiche porte ce nom sans
  // ambiguïté.
  describe("même nom renvoyé, lien incohérent => lien corrigé", () => {
    const stale = { assignedAdvisorName: "Awa Koné", counsellorId: JOJO.id };

    it("assignCase « à Awa » : relié à Awa, Jojo perd l'accès, alerte à Awa", async () => {
      const { svc, row, mails } = makeWorld([JOJO, AWA], stale);
      await expectAccess(svc, jojoActor);
      expect(await alertRecipient(svc, mails)).toBe("jojo@kpb.test");

      await svc.assignCase("case-1", { assignedAdvisorName: "Awa Koné" });

      expect(row.counsellorId).toBe(AWA.id);
      await expectNoAccess(svc, jojoActor);
      await expectAccess(svc, awaActor);
      expect(await alertRecipient(svc, mails)).toBe("awa@kpb.test");
    });

    it("PATCH avec le même nom : relié à Awa, Jojo perd l'accès", async () => {
      const { svc, row } = makeWorld([JOJO, AWA], stale);
      await svc.update("case-1", {
        assignedAdvisorName: " awa koné ",
        nextStepTitle: "Appel prévu",
      });
      expect(row.counsellorId).toBe(AWA.id);
      await expectNoAccess(svc, jojoActor);
    });

    it("lien nul puis fiche créée : relié à la fiche", async () => {
      const { svc, row, mails } = makeWorld([JOJO, AWA], {
        assignedAdvisorName: "Awa Koné",
        counsellorId: null,
      });
      await svc.assignCase("case-1", { assignedAdvisorName: "Awa Koné" });
      expect(row.counsellorId).toBe(AWA.id);
      expect(await alertRecipient(svc, mails)).toBe("awa@kpb.test");
    });

    it("lien nul et aucune fiche : reste nul", async () => {
      const { svc, row } = makeWorld([JOJO, AWA], {
        assignedAdvisorName: "Fatou Externe",
        counsellorId: null,
      });
      await svc.assignCase("case-1", { assignedAdvisorName: "Fatou Externe" });
      expect(row.counsellorId).toBeNull();
    });

    it("conseiller lié qui porte le nom par son compte admin : lien conservé", async () => {
      const { svc, row } = makeWorld([JOJO, AWA], {
        assignedAdvisorName: "Awa K. (KPB)",
        counsellorId: AWA.id,
      });
      await svc.assignCase("case-1", { assignedAdvisorName: "awa k. (kpb)" });
      expect(row.counsellorId).toBe(AWA.id);
    });

    it("résolution ambiguë : rien n'est changé (arbitrage documenté)", async () => {
      const activeTwin = {
        ...AWA,
        id: "c-awa-twin",
        adminUserId: "admin-awa-twin",
        createdAt: new Date("2025-01-01"),
      };
      const { svc, row } = makeWorld([JOJO, AWA, activeTwin], stale);
      await svc.assignCase("case-1", { assignedAdvisorName: "Awa Koné" });
      expect(row.counsellorId).toBe(JOJO.id);
    });
  });

  describe("PATCH par un conseiller", () => {
    it("ne peut pas changer le nom d'affectation (403, rien n'est écrit)", async () => {
      const { svc, row } = makeWorld();
      await expect(
        svc.updateAsStaff(
          "case-1",
          { assignedAdvisorName: "Awa Koné", nextStepTitle: "x" },
          jojoActor,
        ),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(row.assignedAdvisorName).toBe("Jojo Mensah");
      expect(row.counsellorId).toBe(JOJO.id);
      expect(row.nextStepTitle).toBeUndefined();
    });

    it("peut renvoyer le même nom (formulaire pré-rempli)", async () => {
      const { svc, row } = makeWorld();
      await svc.updateAsStaff(
        "case-1",
        { assignedAdvisorName: " jojo mensah", nextStepTitle: "Appel prévu" },
        jojoActor,
      );
      expect(row.counsellorId).toBe(JOJO.id);
      expect(row.nextStepTitle).toBe("Appel prévu");
    });

    it("l'équipe (admin) peut toujours réaffecter par PATCH", async () => {
      const { svc, row } = makeWorld();
      await svc.updateAsStaff(
        "case-1",
        { assignedAdvisorName: "Awa Koné" },
        { role: InternalRole.Admin },
      );
      expect(row.counsellorId).toBe(AWA.id);
    });
  });
});
