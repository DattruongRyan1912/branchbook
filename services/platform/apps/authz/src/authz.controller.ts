import { Controller, Get } from '@nestjs/common';

@Controller()
export class AuthzController {
  @Get('health')
  health() {
    return { status: 'ok', service: 'authz' };
  }
}
