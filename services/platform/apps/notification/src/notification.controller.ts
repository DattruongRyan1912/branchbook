import { Controller, Get } from '@nestjs/common';

@Controller()
export class NotificationController {
  @Get('health')
  health() {
    return { status: 'ok', service: 'notification' };
  }
}
