import type { Spec } from '../../../specs/NativeScreenTime';

/**
 * The browser has no Screen Time, and saying so is the whole job.
 *
 * Without this file the web preview dies at import: `getEnforcing` hard-throws
 * when the TurboModule is missing, before any screen renders. Every method here
 * rejects rather than resolving with a plausible value, because a preview that
 * silently reported "monitoring started" would be exactly the lie the migration
 * brief forbids.
 */
const unavailable = (method: string) => (): Promise<never> =>
  Promise.reject(new Error(`Screen Time is unavailable on web (called ${method}).`));

const webStub: Spec = {
  getAuthorizationStatus: () => Promise.resolve('unavailable'),
  requestAuthorization: () => Promise.resolve('unavailable'),
  presentFamilyActivityPicker: unavailable('presentFamilyActivityPicker'),
  getSelectionSummary: () =>
    Promise.resolve({ applicationCount: 0, categoryCount: 0, webDomainCount: 0, isEmpty: true }),
  configureSchedule: unavailable('configureSchedule'),
  startMonitoring: unavailable('startMonitoring'),
  stopMonitoring: unavailable('stopMonitoring'),
  triggerTestPause: unavailable('triggerTestPause'),
  restoreScreenAccess: unavailable('restoreScreenAccess'),
  disablePottyPause: unavailable('disablePottyPause'),
  getSystemStatus: () =>
    Promise.resolve({
      authorization: 'unavailable',
      isMonitoring: false,
      isShieldUp: false,
      hasSelection: false,
      pauseEndsAt: 0,
      attentionCode: '',
    }),
  addListener: () => {},
  removeListeners: () => {},
} as Spec;

export default webStub;
export type { Spec };
