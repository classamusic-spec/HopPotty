import { Platform } from 'react-native';

import Native from './NativeScreenTime';
import {
  AUTHORIZATION_STATUSES,
  type AttentionCode,
  type AuthorizationStatus,
  type PickerResult,
  type PottyPauseCapabilities,
  type PottyScheduleConfiguration,
  type ScreenTimeSystemStatus,
  type SelectionSummary,
} from './types';

/**
 * The app's view of Screen Time.
 *
 * Two jobs, both boundary work. It narrows the blunt types codegen forces on
 * the native spec into the product's own vocabulary, and it answers the
 * capability question honestly per platform.
 *
 * It deliberately holds no cached state. Native is authoritative for system
 * truth — a shield can be raised or cleared by an extension while this process
 * is not running — so anything cached here would be a second, stale answer
 * that screens might trust over the real one.
 */

const asAuthorization = (value: string): AuthorizationStatus =>
  (AUTHORIZATION_STATUSES as readonly string[]).includes(value)
    ? (value as AuthorizationStatus)
    : 'unavailable';

const ATTENTION_CODES: readonly AttentionCode[] = [
  '',
  'authorizationLost',
  'selectionEmpty',
  'monitoringFailed',
  'shieldClearFailed',
  'sharedStateUnavailable',
];

const asAttention = (value: string): AttentionCode =>
  (ATTENTION_CODES as readonly string[]).includes(value) ? (value as AttentionCode) : '';

export function capabilities(): PottyPauseCapabilities {
  if (Platform.OS === 'ios') {
    return {
      canShieldApps: true,
      canScheduleMonitoring: true,
      canPresentSystemPicker: true,
      unavailableReason: null,
    };
  }
  // Never claim otherwise. Android has no Family Controls equivalent, and a
  // parent told their child's apps are paused when they are not is the single
  // worst failure this product can have.
  return {
    canShieldApps: false,
    canScheduleMonitoring: false,
    canPresentSystemPicker: false,
    unavailableReason:
      Platform.OS === 'android'
        ? 'Potty Pause needs Apple Screen Time, which Android does not provide.'
        : 'Potty Pause is only available on iPhone and iPad.',
  };
}

export const ScreenTimeService = {
  capabilities,

  async getAuthorizationStatus(): Promise<AuthorizationStatus> {
    return asAuthorization(await Native.getAuthorizationStatus());
  },

  async requestAuthorization(): Promise<AuthorizationStatus> {
    return asAuthorization(await Native.requestAuthorization());
  },

  presentFamilyActivityPicker(): Promise<PickerResult> {
    return Native.presentFamilyActivityPicker();
  },

  getSelectionSummary(): Promise<SelectionSummary> {
    return Native.getSelectionSummary();
  },

  configureSchedule(configuration: PottyScheduleConfiguration): Promise<void> {
    return Native.configureSchedule(configuration);
  },

  startMonitoring: (): Promise<void> => Native.startMonitoring(),
  stopMonitoring: (): Promise<void> => Native.stopMonitoring(),
  triggerTestPause: (): Promise<void> => Native.triggerTestPause(),
  restoreScreenAccess: (): Promise<void> => Native.restoreScreenAccess(),
  disablePottyPause: (): Promise<void> => Native.disablePottyPause(),

  async getSystemStatus(): Promise<ScreenTimeSystemStatus> {
    const raw = await Native.getSystemStatus();
    return {
      authorization: asAuthorization(raw.authorization),
      isMonitoring: raw.isMonitoring,
      isShieldUp: raw.isShieldUp,
      hasSelection: raw.hasSelection,
      pauseEndsAt: raw.pauseEndsAt > 0 ? new Date(raw.pauseEndsAt) : null,
      attention: asAttention(raw.attentionCode),
    };
  },
};

export type ScreenTimeServiceType = typeof ScreenTimeService;
