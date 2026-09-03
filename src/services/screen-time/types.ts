/**
 * The Screen Time vocabulary the product speaks.
 *
 * These are the strong types the app uses everywhere. The native spec deals in
 * `string` because codegen has no unions; narrowing happens once, in
 * `ScreenTimeService`, so an unrecognised value from native becomes a typed
 * `unavailable` at the boundary rather than an unchecked string leaking into
 * fifty screens.
 */

export type AuthorizationStatus =
  | 'notDetermined'
  | 'denied'
  | 'approved'
  /** The device cannot do Screen Time at all — no entitlement, or not iOS. */
  | 'unavailable';

export const AUTHORIZATION_STATUSES: readonly AuthorizationStatus[] = [
  'notDetermined',
  'denied',
  'approved',
  'unavailable',
];

/** What the parent picked, described without revealing what it is. */
export interface SelectionSummary {
  readonly applicationCount: number;
  readonly categoryCount: number;
  readonly webDomainCount: number;
  readonly isEmpty: boolean;
}

export interface PickerResult extends Omit<SelectionSummary, 'isEmpty'> {
  readonly cancelled: boolean;
}

export interface PottyScheduleConfiguration {
  readonly pauseDurationSeconds: number;
  readonly intervalSeconds: number;
  /** 1 = Sunday, matching `Calendar.component(.weekday)`. */
  readonly activeDayNumbers: readonly number[];
  readonly activeWindowStartMinutes: number;
  readonly activeWindowEndMinutes: number;
  readonly quietRanges: readonly { readonly startMinutes: number; readonly endMinutes: number }[];
  readonly cooldownSeconds: number;
  readonly warningOffsetSeconds: number;
}

/**
 * Why the native layer wants a caregiver to look at something.
 *
 * Empty string means "nothing wrong", which is the overwhelmingly common case
 * and is why this is a code rather than an optional object.
 */
export type AttentionCode =
  | ''
  | 'authorizationLost'
  | 'selectionEmpty'
  | 'monitoringFailed'
  | 'shieldClearFailed'
  | 'sharedStateUnavailable';

export interface ScreenTimeSystemStatus {
  readonly authorization: AuthorizationStatus;
  readonly isMonitoring: boolean;
  readonly isShieldUp: boolean;
  readonly hasSelection: boolean;
  /** `null` when no pause is running. */
  readonly pauseEndsAt: Date | null;
  readonly attention: AttentionCode;
}

/**
 * Events the native layer pushes up.
 *
 * Deliberately few and deliberately product-level. The native side emits when
 * something changed that a screen would want to redraw for — not a running
 * commentary of framework callbacks.
 */
export type ScreenTimeEvent =
  | { readonly type: 'authorizationChanged'; readonly status: AuthorizationStatus }
  | { readonly type: 'monitoringChanged'; readonly isMonitoring: boolean }
  | { readonly type: 'pauseTriggered'; readonly endsAt: Date }
  | { readonly type: 'pauseEnded'; readonly at: Date }
  | { readonly type: 'scheduleChanged' }
  | { readonly type: 'needsAttention'; readonly code: AttentionCode };

export type ScreenTimeEventType = ScreenTimeEvent['type'];

/**
 * Whether this platform can actually do any of this.
 *
 * Android has no Family Controls equivalent, and the migration brief is
 * explicit that we must never pretend apps are blocked when they are not. So
 * capability is asked, not assumed, and the Android implementation answers
 * honestly rather than returning a plausible-looking lie.
 */
export interface PottyPauseCapabilities {
  readonly canShieldApps: boolean;
  readonly canScheduleMonitoring: boolean;
  readonly canPresentSystemPicker: boolean;
  /** Shown to a caregiver when the platform cannot do this at all. */
  readonly unavailableReason: string | null;
}
