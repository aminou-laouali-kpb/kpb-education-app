import { beforeEach, describe, expect, it, vi } from 'vitest';

import { apiFetch } from './api-client';
import {
  activateScholarshipCycle,
  cancelOpening,
  fetchOpeningOverview,
  fetchOpeningPreview,
  fetchOpeningReport,
  fetchOpeningTodo,
  saveScholarshipForecast,
  stopOpening,
} from './scholarship-opening-api';

vi.mock('./api-client', () => ({
  apiFetch: vi.fn(),
}));

const apiFetchMock = vi.mocked(apiFetch);

describe('client de l’annonce d’ouverture', () => {
  beforeEach(() => {
    apiFetchMock.mockReset();
  });

  it('demande l’aperçu par défaut sans paramètre', () => {
    void fetchOpeningPreview('chevening');
    expect(apiFetchMock).toHaveBeenCalledWith(
      '/admin/scholarships/chevening/opening-preview',
      { signal: undefined },
    );
  });

  it('passe l’année et les dates de l’aperçu, et le signal d’abandon', () => {
    const controller = new AbortController();
    void fetchOpeningPreview(
      'chevening',
      {
        academicYear: '2027-2028',
        opensAt: '2027-10-01T00:00:00.000Z',
        closesAt: '2027-11-05T23:59:59.999Z',
      },
      controller.signal,
    );
    expect(apiFetchMock).toHaveBeenCalledWith(
      '/admin/scholarships/chevening/opening-preview' +
        '?academicYear=2027-2028' +
        '&opensAt=2027-10-01T00%3A00%3A00.000Z' +
        '&closesAt=2027-11-05T23%3A59%3A59.999Z',
      { signal: controller.signal },
    );
  });

  it('ouvre le cycle avec notify et le nombre confirmé', () => {
    const body = {
      academicYear: '2027-2028',
      opensAt: '2027-10-01T00:00:00.000Z',
      closesAt: '2027-11-05T23:59:59.999Z',
      dateConfidence: 'confirmed' as const,
      notify: true,
      expectedRecipients: 312,
    };
    void activateScholarshipCycle('chevening', body);
    expect(apiFetchMock).toHaveBeenCalledWith('/admin/scholarships/chevening/activate', {
      method: 'POST',
      body,
    });
  });

  it('enregistre une prévision sur la route existante', () => {
    const body = {
      academicYear: '2027-2028',
      estimatedOpenAt: '2027-09-15T00:00:00.000Z',
      estimatedCloseAt: '2027-11-01T23:59:59.999Z',
    };
    void saveScholarshipForecast('chevening', body);
    expect(apiFetchMock).toHaveBeenCalledWith('/admin/scholarships/chevening/forecast', {
      method: 'POST',
      body,
    });
  });

  it('annule et arrête par cycle, sans corps', () => {
    void cancelOpening('chevening', 'cyc_1');
    void stopOpening('chevening', 'cyc_1');
    expect(apiFetchMock).toHaveBeenNthCalledWith(
      1,
      '/admin/scholarships/chevening/cycles/cyc_1/opening/cancel',
      { method: 'POST' },
    );
    expect(apiFetchMock).toHaveBeenNthCalledWith(
      2,
      '/admin/scholarships/chevening/cycles/cyc_1/opening/stop',
      { method: 'POST' },
    );
  });

  it('lit le rapport d’un cycle', () => {
    void fetchOpeningReport('chevening', 'cyc_1');
    expect(apiFetchMock).toHaveBeenCalledWith(
      '/admin/scholarships/chevening/cycles/cyc_1/opening-report',
      { signal: undefined },
    );
  });

  it('encode les identifiants dans le chemin', () => {
    void cancelOpening('bourse/2027 #1', 'c?1');
    expect(apiFetchMock).toHaveBeenCalledWith(
      '/admin/scholarships/bourse%2F2027%20%231/cycles/c%3F1/opening/cancel',
      { method: 'POST' },
    );
  });

  it('lit « À faire » et les colonnes de la liste', () => {
    void fetchOpeningTodo();
    void fetchOpeningOverview();
    expect(apiFetchMock).toHaveBeenNthCalledWith(1, '/admin/scholarships/opening-todo');
    expect(apiFetchMock).toHaveBeenNthCalledWith(2, '/admin/scholarships/opening-overview');
  });
});
