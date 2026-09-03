const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');

/**
 * Metro serves the native app only. The browser preview is built by Vite —
 * see web-preview/. Metro's own web support is undocumented outside Expo and
 * would be a bespoke build to own forever.
 */
module.exports = mergeConfig(getDefaultConfig(__dirname), {
  resolver: {
    // `HopPottyKit` is Swift and `web/` is the old static prototype; walking
    // either wastes watcher budget and can shadow real modules.
    blockList: [/\/HopPottyKit\/.*/, /\/web\/dist\/.*/, /\/Art\/render\/.*/],
  },
});
