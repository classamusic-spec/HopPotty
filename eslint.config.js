// Flat config. `@react-native/eslint-config` ships a `./flat` export; the RN
// template still uses the legacy .eslintrc, which is the older of the two.
const reactNative = require('@react-native/eslint-config/flat');

module.exports = [
  { ignores: ['node_modules/**', 'web-preview/dist/**', '**/*.generated.ts', 'web/**'] },
  ...reactNative,
  {
    rules: {
      // The migration brief forbids `any` without a documented interop reason,
      // so it is an error here rather than a warning nobody reads.
      '@typescript-eslint/no-explicit-any': 'error',
      'no-console': ['warn', { allow: ['warn', 'error'] }],
    },
  },
];
