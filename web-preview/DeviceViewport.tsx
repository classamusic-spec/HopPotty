import React, { createContext, useContext, useMemo } from 'react';

/**
 * The device a screen believes it is on.
 *
 * Every ported screen asks `useWindowDimensions()` and branches on the answer:
 * `isRegular`/`isWide` picks the iPad split view over the phone stack, and the
 * games size their board from it. In a browser that hook reports the *browser
 * window*, so a 1280px laptop would render every parent screen's iPad sidebar
 * inside a 393pt phone frame — the preview would be showing a layout the phone
 * never has.
 *
 * So the browser preview supplies the device size explicitly. `react-native.ts`
 * resolves `react-native` for the preview build and reads this context inside
 * `useWindowDimensions`, which puts every screen back on the device the browser
 * says it is drawing.
 */

export type DeviceName = 'phone' | 'ipad';

export interface DeviceFrame {
  readonly width: number;
  readonly height: number;
}

/**
 * The two frames the browser draws.
 *
 * A 6.1" iPhone in points, and an iPad in landscape — the two sizes
 * `Art/render/screens/` is rendered at, so a screen and its reference PNG are
 * compared at the same size.
 */
export const DEVICE_FRAME: Readonly<Record<DeviceName, DeviceFrame>> = {
  phone: { width: 393, height: 852 },
  ipad: { width: 1024, height: 768 },
};

/** What React Native's `useWindowDimensions()` returns. */
export interface WindowDimensions extends DeviceFrame {
  readonly scale: number;
  readonly fontScale: number;
}

const DeviceViewportContext = createContext<WindowDimensions | null>(null);

/**
 * The device size in force, or `null` outside a frame — which is the honest
 * answer for the preview's own chrome, and leaves the real window in charge.
 */
export function useDeviceViewport(): WindowDimensions | null {
  return useContext(DeviceViewportContext);
}

export function DeviceViewport({
  device,
  children,
}: {
  device: DeviceName;
  children: React.ReactNode;
}): React.ReactElement {
  const frame = DEVICE_FRAME[device];
  const value = useMemo<WindowDimensions>(
    // Points, not pixels: the screens reason in points, and a browser preview
    // has no business claiming a Retina scale factor it cannot honour.
    () => ({ width: frame.width, height: frame.height, scale: 1, fontScale: 1 }),
    [frame.width, frame.height],
  );
  return <DeviceViewportContext.Provider value={value}>{children}</DeviceViewportContext.Provider>;
}
