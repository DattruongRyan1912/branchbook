import { defineConfig } from 'vitest/config';

export default defineConfig({
  // Vite tự đọc alias trong "paths" của tsconfig.json (chưa dùng; sẵn cho libs/ sau này).
  resolve: { tsconfigPaths: true },
  test: {
    globals: true,
    root: './',
    include: ['**/*.spec.ts'],
  },
});
