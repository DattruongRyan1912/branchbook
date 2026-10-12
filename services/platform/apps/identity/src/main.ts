import { NestFactory } from '@nestjs/core';
import { IdentityModule } from './identity.module.js';

async function bootstrap() {
  const app = await NestFactory.create(IdentityModule);
  app.enableShutdownHooks();
  await app.listen(process.env.PORT ?? 3000);
}
void bootstrap();
