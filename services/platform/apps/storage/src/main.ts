import { NestFactory } from '@nestjs/core';
import { StorageModule } from './storage.module.js';

async function bootstrap() {
  const app = await NestFactory.create(StorageModule);
  app.enableShutdownHooks();
  await app.listen(process.env.PORT ?? 3000);
}
void bootstrap();
