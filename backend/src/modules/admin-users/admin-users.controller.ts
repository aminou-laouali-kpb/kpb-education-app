import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AdminUsersService } from './admin-users.service';
import { CreateAdminUserDto } from './dto/create-admin-user.dto';
import { UpdateAdminUserDto } from './dto/update-admin-user.dto';

@Controller('admin/users')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin)
export class AdminUsersController {
  constructor(private readonly adminUsersService: AdminUsersService) {}

  @Get()
  listUsers() {
    return this.adminUsersService.listUsers();
  }

  @Post()
  createUser(@Body() input: CreateAdminUserDto, @Req() req: any) {
    assertCanGrant(req.adminUser?.role, input.role);
    return this.adminUsersService.createUser(input);
  }

  @Patch(':id')
  async updateUser(
    @Param('id') id: string,
    @Body() input: UpdateAdminUserDto,
    @Req() req: any,
  ) {
    await this.assertCanManage(req.adminUser?.role, id);
    if (input.role) assertCanGrant(req.adminUser?.role, input.role);
    return this.adminUsersService.updateUser(id, input);
  }

  /**
   * Issue a fresh temporary password for an operator and invalidate their
   * existing sessions. The plaintext temp password is returned ONCE so the
   * admin can hand it over; only the bcrypt hash is stored.
   */
  @Post(':id/reset-password')
  async resetPassword(@Param('id') id: string, @Req() req: any) {
    // Un Admin pouvait réinitialiser le mot de passe d'un SuperAdmin et
    // récupérer le mot de passe temporaire : prise de compte du rôle supérieur.
    await this.assertCanManage(req.adminUser?.role, id);
    return this.adminUsersService.resetPassword(id);
  }

  private async assertCanManage(actorRole: string | undefined, targetId: string) {
    if (actorRole === InternalRole.SuperAdmin) return;
    if ((await this.adminUsersService.getRole(targetId)) === InternalRole.SuperAdmin) {
      throw new ForbiddenException('Only a super admin can manage a super admin.');
    }
  }
}

/** Seul un SuperAdmin peut créer ou promouvoir un SuperAdmin. */
function assertCanGrant(actorRole: string | undefined, role: InternalRole) {
  if (role === InternalRole.SuperAdmin && actorRole !== InternalRole.SuperAdmin) {
    throw new ForbiddenException('Only a super admin can grant the super admin role.');
  }
}
