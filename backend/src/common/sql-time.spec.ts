import { SQL_NOW_UTC, utcTimestamp } from './sql-time';

describe('sql-time', () => {
  it('convertit une date en timestamp UTC, paramètre lié', () => {
    const date = new Date('2026-11-14T12:00:00.000Z');
    const sql = utcTimestamp(date);

    expect(sql.text).toBe("($1::timestamptz AT TIME ZONE 'UTC')");
    expect(sql.values).toEqual([date]);
  });

  it("donne now() en heure UTC, sans paramètre", () => {
    expect(SQL_NOW_UTC.text).toBe("(now() AT TIME ZONE 'UTC')");
    expect(SQL_NOW_UTC.values).toEqual([]);
  });
});
