/**
 * The Screen Time module is native and has no JS implementation, so every test
 * that renders a screen touching it would otherwise throw at import time.
 * `TurboModuleRegistry.getEnforcing` is deliberately unforgiving.
 */
jest.mock('./src/services/screen-time/NativeScreenTime', () =>
  require('./src/services/screen-time/screenTimeMock').createMockScreenTime(),
);
