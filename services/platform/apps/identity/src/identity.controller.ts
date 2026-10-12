import { Controller, Get } from '@nestjs/common';

@Controller()
export class IdentityController {
  @Get('health')
  health() {
    return { status: 'ok', service: 'identity' };
  }
}
