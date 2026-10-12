import { Controller, Get } from '@nestjs/common';

@Controller()
export class StorageController {
  @Get('health')
  health() {
    return { status: 'ok', service: 'storage' };
  }
}
