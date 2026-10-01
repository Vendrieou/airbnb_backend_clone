import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  resolve: { alias: { '@': new URL('./src', import.meta.url).pathname } },
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      // semua request API diarahkan ke Rails (http://localhost:3000)
      '/api': { target: 'http://localhost:3000', changeOrigin: true },
      // endpoint yang dipakai frontend (lihat pola proxy yang sama utk rental/housekeeping)
      '/master_data': { target: 'http://localhost:3000', changeOrigin: true },
      '/conversations': { target: 'http://localhost:3000', changeOrigin: true },
      '/cable': { target: 'http://localhost:3000', changeOrigin: true, ws: true },
    },
  },
});
