import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Puerto 5173: es el que el backend permite en CORS ("Frontend:Url" en appsettings.json).
// Proxy opcional: si VITE_API_URL se deja vacío, las llamadas a /api pasan por Vite hacia el backend local.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    strictPort: true,
    open: true,
    proxy: { '/api': { target: 'http://localhost:5000', changeOrigin: true } },
  },
})
