import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

/**
 * The native Screen Time surface, as React Native codegen sees it.
 *
 * ## What belongs here
 *
 * Product operations, and nothing else. "Start a test pause" belongs; "write
 * this object into ManagedSettings" does not. The migration brief's security
 * boundary is that JavaScript commands the Screen Time system through named
 * intentions it cannot misuse, rather than being handed the system itself —
 * so there is no method here that takes an opaque payload and applies it, and
 * no Apple token ever crosses this boundary.
 *
 * ## Why the types look blunt
 *
 * Codegen accepts primitives, plain object types and arrays. It does not accept
 * string-literal unions, enums or discriminated unions, so statuses arrive as
 * `string` and are narrowed one layer up in `ScreenTimeService.ts`. Widening
 * happens exactly once, at the boundary, and the rest of the app sees the
 * strong types.
 *
 * ## What deliberately is not here
 *
 * `DeviceActivityReport` is a SwiftUI view rendered in a separate extension
 * process. Its data cannot cross a bridge — no bridge, not this one, not
 * Nitro. If we ever surface it, it is as a native view hosted inside React
 * Native, never as a method returning numbers.
 */
export interface Spec extends TurboModule {
  /** `notDetermined` | `denied` | `approved` | `unavailable`. */
  getAuthorizationStatus(): Promise<string>;

  /**
   * Presents Apple's own authorization prompt. Resolves with the resulting
   * status; rejects only if the request could not be made at all.
   */
  requestAuthorization(): Promise<string>;

  /**
   * Presents `FamilyActivityPicker`, which Apple requires be shown natively —
   * the selection it returns is a set of opaque tokens that must never be
   * decoded, logged or sent to JavaScript.
   *
   * Resolves with counts only, which is all a parent-facing screen needs to
   * say "4 apps and 1 category will pause".
   */
  presentFamilyActivityPicker(): Promise<{
    applicationCount: number;
    categoryCount: number;
    webDomainCount: number;
    cancelled: boolean;
  }>;

  /** The current selection's shape, without revealing what is in it. */
  getSelectionSummary(): Promise<{
    applicationCount: number;
    categoryCount: number;
    webDomainCount: number;
    isEmpty: boolean;
  }>;

  /**
   * Writes the pause schedule into the App Group so the monitor extension can
   * read it with the app not running. Every field is validated natively; a
   * rejected configuration throws rather than being silently clamped, because
   * a schedule quietly different from the one a parent set is worse than an
   * error they can see.
   */
  configureSchedule(configuration: {
    pauseDurationSeconds: number;
    intervalSeconds: number;
    activeDayNumbers: ReadonlyArray<number>;
    activeWindowStartMinutes: number;
    activeWindowEndMinutes: number;
    quietRanges: ReadonlyArray<{ startMinutes: number; endMinutes: number }>;
    cooldownSeconds: number;
    warningOffsetSeconds: number;
  }): Promise<void>;

  startMonitoring(): Promise<void>;
  stopMonitoring(): Promise<void>;

  /** Raises a real pause now, for onboarding's "try it" step and the debug lab. */
  triggerTestPause(): Promise<void>;

  /**
   * The caregiver override. Clears the shield and cancels monitoring, asks no
   * questions and cannot decline — the native side treats this as an emergency
   * exit, which is why it is exposed as its own verb rather than as a flag on
   * something else.
   */
  restoreScreenAccess(): Promise<void>;

  /** Turns the feature off entirely: clears, cancels, and forgets the schedule. */
  disablePottyPause(): Promise<void>;

  getSystemStatus(): Promise<{
    authorization: string;
    isMonitoring: boolean;
    isShieldUp: boolean;
    hasSelection: boolean;
    /** Epoch millis, or 0 when no pause is running. */
    pauseEndsAt: number;
    /** Non-empty when the native layer wants a caregiver to look at something. */
    attentionCode: string;
  }>;

  addListener(eventName: string): void;
  removeListeners(count: number): void;
}

export default TurboModuleRegistry.getEnforcing<Spec>('NativeScreenTime');
