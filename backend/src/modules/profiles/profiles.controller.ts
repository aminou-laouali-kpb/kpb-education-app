import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpStatus,
  Patch,
  Post,
  Req,
  Res,
  UploadedFile,
  UseFilters,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { ProfileAvatarPayloadFilter } from './profile-avatar-payload.filter';
import { avatarFileRequired } from './profile-avatar.errors';
import { AVATAR_MULTIPART_BYTE_CEILING } from './profile-avatar.policy';
import {
  ProfilesService,
  type UploadedAvatarFile,
} from './profiles.service';

@Controller('profiles')
@UseGuards(StudentAuthGuard)
export class ProfilesController {
  constructor(private readonly profilesService: ProfilesService) {}

  @Get('me')
  getMe(@Req() req: any) {
    return this.profilesService.getMe(req.studentUser?.id);
  }

  @Patch('me')
  updateMe(@Body() payload: UpdateProfileDto, @Req() req: any) {
    return this.profilesService.updateMe(payload, req.studentUser?.id);
  }

  // ── Profile photo ──────────────────────────────────────────────────────────
  // Multipart field `file`, 2 MB, JPEG/PNG/WebP. Returns the updated profile,
  // the same shape as GET/PATCH /profiles/me.
  @Post('me/avatar')
  @UseFilters(ProfileAvatarPayloadFilter)
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: AVATAR_MULTIPART_BYTE_CEILING, files: 1 },
    }),
  )
  uploadAvatar(
    @UploadedFile() file: UploadedAvatarFile | undefined,
    @Req() req: any,
  ) {
    if (!file?.buffer) throw avatarFileRequired();
    return this.profilesService.uploadAvatar(file, req.studentUser?.id);
  }

  // Authenticated image delivery. There is no public URL for an avatar: the
  // guard above plus the per-row ownership check in the service are the only way
  // to reach the bytes, because a profile photo can be a minor's face.
  @Get('me/avatar')
  async getAvatar(
    @Req() req: any,
    @Headers('if-none-match') ifNoneMatch: string | undefined,
    @Res() response: Response,
  ): Promise<void> {
    const avatar = await this.profilesService.streamAvatar(
      req.studentUser?.id,
      ifNoneMatch,
    );

    response.setHeader('ETag', avatar.etag);
    // `private` keeps the image out of shared caches while still letting the
    // student's own device reuse it — the audience pays for data by the
    // megabyte, so a revalidation must not re-download the whole file.
    response.setHeader('Cache-Control', 'private, max-age=300, must-revalidate');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Content-Security-Policy', "default-src 'none'; sandbox");
    response.setHeader('Cross-Origin-Resource-Policy', 'same-origin');

    if (!avatar.object) {
      response.status(HttpStatus.NOT_MODIFIED).end();
      return;
    }

    response.setHeader('Content-Type', avatar.object.mimeType);
    response.setHeader('Content-Disposition', 'inline; filename="avatar"');
    if (avatar.object.sizeBytes !== undefined) {
      response.setHeader('Content-Length', avatar.object.sizeBytes.toString());
    }
    avatar.object.stream.on('error', () => {
      if (!response.headersSent) response.status(503).end();
      else response.destroy();
    });
    avatar.object.stream.pipe(response);
  }

  @Delete('me/avatar')
  deleteAvatar(@Req() req: any) {
    return this.profilesService.deleteAvatar(req.studentUser?.id);
  }

  // « Effacer ma nationalité » (test « Mes 10 bourses ») : efface la ou les
  // nationalités du profil et les résultats calculés avec elles.
  @Delete('me/nationality')
  eraseNationality(@Req() req: any) {
    return this.profilesService.eraseNationality(req.studentUser?.id);
  }

  // GDPR data export (portability) — returns one JSON document of all the
  // caller's records.
  @Get('me/export')
  exportMe(@Req() req: any) {
    return this.profilesService.exportMe(req.studentUser?.id);
  }

  // GDPR / store-required account deletion — hard-deletes the caller's Supabase
  // identity and local data, failing closed if either deletion cannot complete.
  @Delete('me')
  deleteMe(@Req() req: any) {
    return this.profilesService.deleteMe(req.studentUser?.id);
  }
}
