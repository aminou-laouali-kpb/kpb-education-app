import { CatalogController } from './catalog.controller';
import { CatalogService } from './catalog.service';

describe('CatalogController — programs pagination params', () => {
  function call(limit?: string, offset?: string) {
    let captured: Record<string, unknown> = {};
    const service = {
      getPrograms: (q: Record<string, unknown>) => {
        captured = q;
        return { items: [] };
      },
    } as unknown as CatalogService;
    new CatalogController(service).programs(undefined, undefined, undefined, undefined, limit, offset);
    return captured;
  }

  it('ignores non-integer limit/offset instead of forwarding NaN', () => {
    expect(call('abc', '1.5')).toMatchObject({ limit: undefined, offset: undefined });
    expect(call('-3', ' ')).toMatchObject({ limit: undefined, offset: undefined });
  });

  it('forwards valid integers', () => {
    expect(call('20', '40')).toMatchObject({ limit: 20, offset: 40 });
  });
});
