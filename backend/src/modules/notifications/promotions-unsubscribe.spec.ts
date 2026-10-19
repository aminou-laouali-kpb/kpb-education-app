import { PromotionsUnsubscribeController } from './promotions-unsubscribe.controller';
import {
  promotionsEmailFooter,
  promotionsUnsubscribeToken,
  promotionsUnsubscribeUrl,
  verifyPromotionsUnsubscribeToken,
} from './promotions-unsubscribe';
import type { PrismaService } from '../prisma/prisma.service';

/** Correctifs 57 (XC-06) : chaque e-mail promotionnel porte un lien qui marche. */
describe('promotions-unsubscribe', () => {
  const env = { KPB_JWT_SECRET: 'jwt-secret' } as NodeJS.ProcessEnv;

  it('signe le lien avec le secret dédié, sinon celui des JWT', () => {
    const url = promotionsUnsubscribeUrl('user_1', env)!;
    expect(url).toMatch(
      /^https:\/\/api\.kpbeducation\.cloud\/api\/public\/promotions\/unsubscribe\?u=user_1&t=[A-Za-z0-9_-]{32}$/,
    );
    const dedicated = promotionsUnsubscribeUrl('user_1', {
      ...env,
      KPB_PROMOTIONS_UNSUBSCRIBE_SECRET: 'other',
      KPB_PUBLIC_API_URL: 'https://api.example.test/api/',
    })!;
    expect(dedicated.startsWith('https://api.example.test/api/public/promotions/unsubscribe?u=user_1&t=')).toBe(
      true,
    );
    expect(dedicated.split('t=')[1]).not.toBe(url.split('t=')[1]);
  });

  it('sans aucun secret : pas de lien (l’e-mail promotionnel ne partira pas)', () => {
    expect(promotionsUnsubscribeUrl('user_1', {} as NodeJS.ProcessEnv)).toBeNull();
    expect(verifyPromotionsUnsubscribeToken('user_1', 'x'.repeat(32), {} as NodeJS.ProcessEnv)).toBe(false);
  });

  it('refuse un jeton d’un autre compte, tronqué ou absent', () => {
    const token = promotionsUnsubscribeToken('user_1', 'jwt-secret');
    expect(verifyPromotionsUnsubscribeToken('user_1', token, env)).toBe(true);
    expect(verifyPromotionsUnsubscribeToken('user_2', token, env)).toBe(false);
    expect(verifyPromotionsUnsubscribeToken('user_1', token.slice(1), env)).toBe(false);
    expect(verifyPromotionsUnsubscribeToken('user_1', undefined, env)).toBe(false);
    expect(verifyPromotionsUnsubscribeToken(['user_1'], token, env)).toBe(false);
  });

  it('le pied d’e-mail porte le lien, en français et en anglais', () => {
    expect(promotionsEmailFooter('https://x/u', 'fr')).toContain('Te désinscrire en un clic : https://x/u');
    expect(promotionsEmailFooter('https://x/u', 'en')).toContain('Unsubscribe in one click: https://x/u');
  });

  describe('PromotionsUnsubscribeController', () => {
    const previous = process.env.KPB_JWT_SECRET;
    const previousDedicated = process.env.KPB_PROMOTIONS_UNSUBSCRIBE_SECRET;
    beforeAll(() => {
      process.env.KPB_JWT_SECRET = 'jwt-secret';
      delete process.env.KPB_PROMOTIONS_UNSUBSCRIBE_SECRET;
    });
    afterAll(() => {
      if (previous === undefined) delete process.env.KPB_JWT_SECRET;
      else process.env.KPB_JWT_SECRET = previous;
      if (previousDedicated !== undefined) process.env.KPB_PROMOTIONS_UNSUBSCRIBE_SECRET = previousDedicated;
    });

    function controller() {
      const writes: unknown[] = [];
      const client = {
        userProfile: {
          updateMany: async (args: unknown) => {
            writes.push(args);
            return { count: 1 };
          },
        },
      };
      const prisma = {
        execute: async (fn: (c: typeof client) => unknown) => fn(client),
      } as unknown as PrismaService;
      return { ctrl: new PromotionsUnsubscribeController(prisma), writes };
    }

    it('GET affiche un bouton et n’écrit rien (un antivirus qui suit le lien ne désinscrit pas)', () => {
      const { ctrl, writes } = controller();
      const token = promotionsUnsubscribeToken('user_1', 'jwt-secret');
      const html = ctrl.confirm('user_1', token);
      expect(html).toContain('<form method="post"');
      expect(html).not.toContain('user_1@');
      expect(writes).toHaveLength(0);
    });

    it('POST désinscrit (idempotent) ; jeton faux : rien n’est écrit', async () => {
      const { ctrl, writes } = controller();
      const token = promotionsUnsubscribeToken('user_1', 'jwt-secret');
      expect(await ctrl.unsubscribe('user_1', token)).toContain('Désinscription faite');
      expect(writes).toEqual([
        { where: { id: 'user_1', promotionsEmailOptIn: true }, data: { promotionsEmailOptIn: false } },
      ]);
      expect(await ctrl.unsubscribe('user_2', token)).toContain('Lien invalide');
      expect(writes).toHaveLength(1);
    });
  });
});
