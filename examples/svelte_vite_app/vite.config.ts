import { svelte } from '@sveltejs/vite-plugin-svelte';
import { defineConfig, type Plugin } from 'vite';

function emitIndex(): Plugin {
  return {
    generateBundle() {
      this.emitFile({
        fileName: 'index.html',
        source:
          '<!doctype html><html lang="en"><head><meta charset="UTF-8" />' +
          '<meta name="viewport" content="width=device-width, initial-scale=1.0" />' +
          '<title>Svelte Vite App</title><script type="module" src="/assets/app.js"></script>' +
          '</head><body><div id="app"></div></body></html>',
        type: 'asset',
      });
    },
    name: 'emit-index',
  };
}

export default defineConfig({
  build: {
    cssCodeSplit: false,
    emptyOutDir: true,
    modulePreload: {
      polyfill: false,
    },
    outDir: 'dist',
    rollupOptions: {
      input: 'src/main.ts',
      output: {
        assetFileNames: 'assets/app[extname]',
        chunkFileNames: 'assets/[name].js',
        entryFileNames: 'assets/app.js',
      },
    },
  },
  plugins: [svelte(), emitIndex()],
  server: {
    host: '127.0.0.1',
  },
});
