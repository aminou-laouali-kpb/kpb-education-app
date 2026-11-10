import { Controller, Get, Query, Req } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Request } from 'express';

import { COSTLY_READ_THROTTLE } from '../../common/throttler-options';

import { FlightCalendarQueryDto } from './dto/flight-calendar.query.dto';
import { FlightRoutesQueryDto } from './dto/flight-routes.query.dto';
import { KayakService } from './kayak.service';
import { FlightCalendarResponse, FlightRoutesResponse } from './kayak.types';

/// Public endpoints — the flight-price estimator is usable pre-login.
/// No auth guard; the global throttler applies. The Kayak secret and affiliate
/// tracking stay server-side (see kayak.service.ts).
///
/// Chaque lecture peut appeler l'API de Kayak : ces routes gardent 60 par
/// minute et par IP, et non les 300 des lectures ordinaires.
@Controller('flights')
@Throttle(COSTLY_READ_THROTTLE)
export class KayakController {
  constructor(private readonly kayakService: KayakService) {}

  @Get('routes')
  getRoutes(
    @Query() query: FlightRoutesQueryDto,
    @Req() req: Request,
  ): Promise<FlightRoutesResponse> {
    return this.kayakService.getRoutes({
      origin: query.origin,
      destination: query.destination,
      departDate: query.departDate,
      returnDate: query.returnDate,
      currency: query.currency,
      userTrackId: query.userTrackId,
      clientIp: this.clientIp(req),
    });
  }

  @Get('calendar')
  getCalendar(
    @Query() query: FlightCalendarQueryDto,
    @Req() req: Request,
  ): Promise<FlightCalendarResponse> {
    return this.kayakService.getCalendar({
      origin: query.origin,
      destination: query.destination,
      dateFrom: query.dateFrom,
      dateTo: query.dateTo,
      aggregation: query.aggregation,
      returnDate: query.returnDate,
      roundTrip: query.roundTrip === 'true',
      currency: query.currency,
      userTrackId: query.userTrackId,
      clientIp: this.clientIp(req),
    });
  }

  /// Real client IP: first hop of `x-forwarded-for` (proxy chain), else req IP.
  private clientIp(req: Request): string | undefined {
    const forwarded = req.headers['x-forwarded-for'];
    const raw = Array.isArray(forwarded) ? forwarded[0] : forwarded;
    if (raw) {
      const first = raw.split(',')[0]?.trim();
      if (first) return first;
    }
    return req.ip ?? undefined;
  }
}
