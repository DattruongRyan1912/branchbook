import { NestFactory } from '@nestjs/core';
import { AuthzModule } from './authz.module.js';

async function bootstrap() {
  const app = await NestFactory.create(AuthzModule);
  app.enableShutdownHooks();
  await app.listen(process.env.PORT ?? 3000);
}
void bootstrap();
