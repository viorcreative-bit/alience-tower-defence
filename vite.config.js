import { defineConfig } from 'vite';

// Göreli yollar: Capacitor içinde ve çevrimdışı açılabilsin.
export default defineConfig({
  base: './',
  server: { host: true },
  build: { chunkSizeWarningLimit: 1000 },
});
