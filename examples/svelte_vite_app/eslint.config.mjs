import js from '@eslint/js';
import svelte from 'eslint-plugin-svelte';
import tseslint from 'typescript-eslint';

const readonly = 'readonly';

export default tseslint.config(
  {
    ignores: ['dist/**', 'node_modules/**', 'test-results/**'],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  ...svelte.configs['flat/recommended'],
  {
    files: ['src/**/*.{svelte,ts}', 'vite.config.ts'],
    languageOptions: {
      globals: {
        document: readonly,
        window: readonly,
      },
    },
  },
  {
    files: ['tests/**/*.mjs'],
    languageOptions: {
      globals: {
        console: readonly,
        process: readonly,
        URL: readonly,
      },
    },
  },
  {
    files: ['**/*.svelte'],
    languageOptions: {
      parserOptions: {
        extraFileExtensions: ['.svelte'],
        parser: tseslint.parser,
      },
    },
  },
);
