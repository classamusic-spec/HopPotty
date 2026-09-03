import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'node:path';

import { createRequire } from 'node:module';

const src = path.resolve(__dirname, '..', 'src');
const require_ = createRequire(path.join(__dirname, 'noop.js'));
const pkg = (id: string): string => require_.resolve(id);

/**
 * The browser preview build.
 *
 * This is a preview surface, not a second production target. It exists so the
 * React Native screens can be reviewed without a Mac, an Xcode build or a
 * device — everything the migration otherwise needs before anyone can see it.
 *
 * Screen Time is absent here by construction, not by omission: the browser has
 * no Family Controls, and `NativeScreenTime.web.ts` rejects rather than
 * returning plausible values, so the preview cannot imply the feature works.
 */
export default defineConfig({
  root: __dirname,
  plugins: [react()],
  define: {
    // React Native's development flag. Vite's `import.meta.env` is not what
    // react-native-web reads.
    __DEV__: JSON.stringify(process.env.NODE_ENV !== 'production'),
    global: 'globalThis',
  },
  resolve: {
    // `src/` lives above this directory, so Vite's upward search for a module
    // never reaches `web-preview/node_modules`. Each shared package is pinned
    // to one resolved copy, which also guarantees a single React instance.
    alias: [
      { find: /^react-native$/, replacement: pkg('react-native-web') },
      { find: /^react-native-web$/, replacement: pkg('react-native-web') },
      { find: /^react-native-svg$/, replacement: pkg('react-native-svg') },
      { find: /^react$/, replacement: pkg('react') },
      { find: /^react\/jsx-runtime$/, replacement: pkg('react/jsx-runtime') },
      { find: /^react\/jsx-dev-runtime$/, replacement: pkg('react/jsx-dev-runtime') },
      { find: /^react-dom$/, replacement: pkg('react-dom') },
      { find: /^react-dom\/client$/, replacement: pkg('react-dom/client') },
      // react-native-web reaches for the asset registry by its React Native
      // package name, but ships its own implementation. The published
      // `@react-native/assets-registry` at RN 0.87 is a thin re-export of
      // `AssetRegistry` from `react-native` — which this config has already
      // aliased to react-native-web, which has no such named export. Installing
      // it therefore yields `undefined` and throws on the first registration.
      // Pointing straight at RNW's own module is what it actually wants.
      {
        find: /^@react-native\/assets-registry\/registry$/,
        replacement: pkg('react-native-web/dist/modules/AssetRegistry'),
      },
      { find: '@', replacement: src },
    ],
    dedupe: ['react', 'react-dom', 'react-native-web'],
    // `.web.*` must win, or `NativeScreenTime.ts` resolves and
    // `TurboModuleRegistry.getEnforcing` throws before anything renders.
    extensions: ['.web.tsx', '.web.ts', '.web.jsx', '.web.js', '.tsx', '.ts', '.jsx', '.js'],
  },
  // The repo root tsconfig extends `@react-native/typescript-config`, which is
  // a native-toolchain dependency the preview deliberately does not install.
  // Supplying the transform settings directly stops esbuild walking up to it.
  esbuild: {
    tsconfigRaw: {
      compilerOptions: {
        target: 'es2022',
        useDefineForClassFields: true,
        jsx: 'react-jsx',
      },
    },
  },
  optimizeDeps: {
    include: ['react-native-web', 'react-native-svg'],
  },
  build: {
    commonjsOptions: { transformMixedEsModules: true },
    outDir: path.resolve(__dirname, 'dist'),
    emptyOutDir: true,
    target: 'es2022',
  },
});
