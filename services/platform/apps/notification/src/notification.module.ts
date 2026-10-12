import { Module } from '@nestjs/common';
import { NotificationController } from './notification.controller.js';

@Module({ controllers: [NotificationController] })
export class NotificationModule {}
