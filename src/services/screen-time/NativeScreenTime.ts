/**
 * The native module, on a platform that has one.
 *
 * `getEnforcing` throws at import time when the module is absent, which is the
 * behaviour we want on iOS — a missing Screen Time module is a broken build,
 * not a degraded mode. Platforms without it resolve `NativeScreenTime.web.ts`
 * or are answered by `capabilities()`.
 */
export { default } from '../../../specs/NativeScreenTime';
export type { Spec } from '../../../specs/NativeScreenTime';
