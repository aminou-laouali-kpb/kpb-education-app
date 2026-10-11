import { Body, Controller, Get, Post, Req, Res, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request, Response } from 'express';

import { ADMIN_LOGIN_THROTTLE } from '../../common/throttler-options';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import {
  ADMIN_REFRESH_COOKIE,
  clearAdminAuthCookies,
  readCookie,
  setAdminAuthCookies,
} from './admin-cookies';
import { AuthService } from './auth.service';
import { AdminLoginDto } from './dto/admin-login.dto';

@Controller('auth/admin')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  @Throttle(ADMIN_LOGIN_THROTTLE)
  async login(
    @Body() input: AdminLoginDto,
    @Res({ passthrough: true }) res: Response,
  ) {
    const { token, refreshToken, user } = await this.authService.login(
      input.email,
      input.password,
    );
    // Tokens go into httpOnly cookies; the JSON body carries only the (non-
    // sensitive) user so the JWTs are never exposed to client-side JavaScript.
    setAdminAuthCookies(res, { token, refreshToken });
    return { user };
  }

  @Post('refresh')
  async refresh(
    @Req() req: Request,
    @Body() input: { refreshToken?: string },
    @Res({ passthrough: true }) res: Response,
  ) {
    const refreshToken =
      readCookie(req.headers.cookie, ADMIN_REFRESH_COOKIE) ??
      input?.refreshToken ??
      '';
    const { token, refreshToken: rotated, user } =
      await this.authService.refresh(refreshToken);
    setAdminAuthCookies(res, { token, refreshToken: rotated });
    return { user };
  }

  @Post('logout')
  async logout(
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    const refreshToken = readCookie(req.headers.cookie, ADMIN_REFRESH_COOKIE);
    try {
      await this.authService.revokeRefreshToken(refreshToken ?? '');
    } catch {
      // Base indisponible : le logout efface quand même les cookies.
    }
    clearAdminAuthCookies(res);
    return { ok: true };
  }

  @Get('session')
  @UseGuards(AdminAuthGuard)
  session(@Req() request: Request & { adminUser: unknown }) {
    return { user: request.adminUser };
  }
}
