import type { Spec } from '../../../specs/NativeScreenTime';

/**
 * A development and test double for the Screen Time module.
 *
 * DEVELOPMENT ONLY. It is never bundled into a release build and never
 * substituted at runtime — `jest.setup.ts` installs it for tests, and the
 * debug lab may use it explicitly. It reports `mock` in places a real device
 * reports a real value so that a screenshot taken against it cannot be
 * mistaken for evidence that Screen Time works.
 */
export interface MockScreenTimeOptions {
  authorization?: string;
  isMonitoring?: boolean;
  isShieldUp?: boolean;
  hasSelection?: boolean;
}

export function createMockScreenTime(options: MockScreenTimeOptions = {}): { default: Spec } {
  let authorization = options.authorization ?? 'notDetermined';
  let isMonitoring = options.isMonitoring ?? false;
  let isShieldUp = options.isShieldUp ?? false;
  let hasSelection = options.hasSelection ?? false;
  let pauseEndsAt = 0;

  const mock: Spec = {
    getAuthorizationStatus: async () => authorization,
    requestAuthorization: async () => {
      authorization = 'approved';
      return authorization;
    },
    presentFamilyActivityPicker: async () => {
      hasSelection = true;
      return { applicationCount: 4, categoryCount: 1, webDomainCount: 0, cancelled: false };
    },
    getSelectionSummary: async () => ({
      applicationCount: hasSelection ? 4 : 0,
      categoryCount: hasSelection ? 1 : 0,
      webDomainCount: 0,
      isEmpty: !hasSelection,
    }),
    configureSchedule: async () => {},
    startMonitoring: async () => {
      isMonitoring = true;
    },
    stopMonitoring: async () => {
      isMonitoring = false;
    },
    triggerTestPause: async () => {
      isShieldUp = true;
      pauseEndsAt = Date.now() + 3 * 60 * 1000;
    },
    restoreScreenAccess: async () => {
      isShieldUp = false;
      pauseEndsAt = 0;
    },
    disablePottyPause: async () => {
      isShieldUp = false;
      isMonitoring = false;
      pauseEndsAt = 0;
    },
    getSystemStatus: async () => ({
      authorization,
      isMonitoring,
      isShieldUp,
      hasSelection,
      pauseEndsAt,
      attentionCode: '',
    }),
    addListener: () => {},
    removeListeners: () => {},
  } as Spec;

  return { default: mock };
}
