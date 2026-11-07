// La boucle de réattribution (07/11/2026) : 81 861 lignes « Dossier
// réattribué » pour 1 241 dossiers en production, parce qu'un dossier sans
// message de conseiller DANS L'APP changeait de conseiller toutes les 10 h,
// indéfiniment. Ces tests rejouent plusieurs jours d'horloge et exigent
// qu'un dossier dont l'étudiant n'a pas réécrit ne bouge qu'une fois.

import {
  CaseReassignmentCronService,
  needsReassignment,
  REASSIGNED_EVENT_TITLE,
} from "./case-reassignment-cron.service";

const H = 60 * 60 * 1000;
const T0 = new Date("2026-11-01T08:00:00.000Z");
const at = (hours: number) => new Date(T0.getTime() + hours * H);

describe("needsReassignment", () => {
  it("ne touche pas un dossier de moins de 10 h", () => {
    expect(needsReassignment({ createdAt: T0 }, at(9.9))).toBe(false);
  });

  it("réattribue un dossier neuf que personne n’a pris en charge en 10 h", () => {
    expect(needsReassignment({ createdAt: T0 }, at(10))).toBe(true);
  });

  it("l’estampille de l’attribution automatique à la création ne vaut pas prise en charge", () => {
    expect(
      needsReassignment(
        {
          createdAt: T0,
          lastCommercialInteractionAt: new Date(T0.getTime() + 50),
        },
        at(11),
      ),
    ).toBe(true);
  });

  it("une seule fois par attente : la réattribution déjà faite clôt l’attente", () => {
    expect(
      needsReassignment({ createdAt: T0, lastReassignedAt: at(10) }, at(20)),
    ).toBe(false);
    expect(
      needsReassignment({ createdAt: T0, lastReassignedAt: at(10) }, at(200)),
    ).toBe(false);
  });

  it("un nouveau message de l’étudiant rouvre l’attente", () => {
    const facts = {
      createdAt: T0,
      lastReassignedAt: at(10),
      lastStudentMessageAt: at(30),
    };
    expect(needsReassignment(facts, at(39))).toBe(false);
    expect(needsReassignment(facts, at(40))).toBe(true);
  });

  it("une réponse de l’équipe, de n’importe quel rôle, met fin à l’attente", () => {
    expect(
      needsReassignment(
        {
          createdAt: T0,
          lastStudentMessageAt: at(1),
          lastStaffMessageAt: at(2),
        },
        at(30),
      ),
    ).toBe(false);
  });

  it("un classement commercial après un échange WhatsApp vaut prise en charge", () => {
    expect(
      needsReassignment(
        { createdAt: T0, lastCommercialInteractionAt: at(3) },
        at(30),
      ),
    ).toBe(false);
  });

  it("une réponse ANTÉRIEURE au dernier message de l’étudiant ne compte pas", () => {
    expect(
      needsReassignment(
        {
          createdAt: T0,
          lastStaffMessageAt: at(2),
          lastStudentMessageAt: at(5),
        },
        at(15),
      ),
    ).toBe(true);
  });
});

// ── Le service, sur une fausse base qui garde l'état entre les passages ──────

type Msg = { senderRole: string; createdAt: Date };
type Ev = { title: string; createdAt: Date };
type FakeCase = {
  id: string;
  counsellorId: string;
  createdAt: Date;
  lastCommercialInteractionAt: Date | null;
  messages: Msg[];
  timelineEvents: Ev[];
};

function fakePrisma(cases: FakeCase[], counsellors = ["richard", "jojo"]) {
  const client: any = {
    case: {
      findMany: jest.fn(async (args: any) => {
        const roles: string[] = args.select.messages.where.senderRole.in;
        return cases
          .filter((c) => c.createdAt < args.where.createdAt.lt)
          .map((c) => ({
            id: c.id,
            counsellorId: c.counsellorId,
            createdAt: c.createdAt,
            lastCommercialInteractionAt: c.lastCommercialInteractionAt,
            messages: c.messages
              .filter((m) => roles.includes(m.senderRole))
              .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime()),
            timelineEvents: c.timelineEvents
              .filter((e) => e.title === args.select.timelineEvents.where.title)
              .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
              .slice(0, 1),
          }));
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const c = cases.find((x) => x.id === where.id)!;
        c.counsellorId = data.counsellorId;
      }),
    },
    counsellor: {
      findMany: jest.fn(async ({ where }: any) =>
        counsellors
          .filter((id) => id !== where.id.not)
          .map((id) => ({ id, fullName: id, _count: { cases: 0 } })),
      ),
    },
    caseTimelineEvent: {
      create: jest.fn(async ({ data }: any) => {
        cases
          .find((x) => x.id === data.caseId)!
          .timelineEvents.push({
            title: data.title,
            createdAt: data.createdAt,
          });
      }),
    },
    $transaction: jest.fn(async (fn: any): Promise<unknown> => fn(client)),
  };
  return {
    isEnabled: true,
    execute: jest.fn(async (fn: any) => fn(client)),
    client,
  };
}

async function runEveryQuarterHour(
  service: CaseReassignmentCronService,
  fromH: number,
  toH: number,
) {
  for (let h = fromH; h <= toH; h += 0.25) {
    await service.reassignUnresponsiveCases(at(h));
  }
}

const reassignments = (c: FakeCase) =>
  c.timelineEvents.filter((e) => e.title === REASSIGNED_EVENT_TITLE).length;

describe("CaseReassignmentCronService", () => {
  const newCase = (over: Partial<FakeCase> = {}): FakeCase => ({
    id: "c1",
    counsellorId: "richard",
    createdAt: T0,
    lastCommercialInteractionAt: new Date(T0.getTime() + 20),
    messages: [{ senderRole: "system", createdAt: T0 }],
    timelineEvents: [{ title: "Conseiller attribué", createdAt: T0 }],
    ...over,
  });

  it("sur 7 jours sans message, un dossier ne change de conseiller qu’UNE fois", async () => {
    const c = newCase();
    const prisma = fakePrisma([c]);
    const service = new CaseReassignmentCronService(prisma as any);

    await runEveryQuarterHour(service, 0, 7 * 24);

    expect(reassignments(c)).toBe(1);
    expect(c.counsellorId).toBe("jojo");
  });

  it("l’étudiant réécrit : une nouvelle réattribution 10 h plus tard, puis plus rien", async () => {
    const c = newCase();
    const prisma = fakePrisma([c]);
    const service = new CaseReassignmentCronService(prisma as any);

    await runEveryQuarterHour(service, 0, 24);
    c.messages.push({ senderRole: "student", createdAt: at(24) });
    await runEveryQuarterHour(service, 24.25, 5 * 24);

    expect(reassignments(c)).toBe(2);
  });

  it("une réponse d’un admin avant 10 h empêche toute réattribution", async () => {
    const c = newCase({
      messages: [
        { senderRole: "student", createdAt: at(1) },
        { senderRole: "admin", createdAt: at(3) },
      ],
    });
    const prisma = fakePrisma([c]);
    const service = new CaseReassignmentCronService(prisma as any);

    await runEveryQuarterHour(service, 0, 3 * 24);

    expect(reassignments(c)).toBe(0);
    expect(c.counsellorId).toBe("richard");
  });

  it("demande à la base les messages des étudiants ET de tous les rôles internes", async () => {
    const prisma = fakePrisma([newCase()]);
    const service = new CaseReassignmentCronService(prisma as any);

    await service.reassignUnresponsiveCases(at(11));

    const roles =
      prisma.client.case.findMany.mock.calls[0][0].select.messages.where
        .senderRole.in;
    expect(roles).toEqual(
      expect.arrayContaining([
        "student",
        "counselor",
        "commercial",
        "admin",
        "super_admin",
        "advisor",
      ]),
    );
  });
});
