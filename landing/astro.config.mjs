// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

// The site lives at the root of usetomate.com. SITE_URL and BASE_PATH can override it
// (for example, to publish under a sub-path).
export default defineConfig({
  site: process.env.SITE_URL || 'https://usetomate.com',
  base: process.env.BASE_PATH || '/',
  vite: {
    plugins: [tailwindcss()],
  },
});
