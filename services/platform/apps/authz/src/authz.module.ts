import { Module } from '@nestjs/common';
import { AuthzController } from './authz.controller.js';

@Module({ controllers: [AuthzController] })
export class AuthzModule {}
