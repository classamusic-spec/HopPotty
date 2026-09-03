import {
  useColorScheme as useBrowserColorScheme,
  useWindowDimensions as useBrowserWindowDimensions,
} from 'react-native-web';
import type { ColorSchemeName, ScaledSize } from 'react-native-web';

import { useDeviceViewport, usePreviewScheme } from './DeviceViewport';

/**
 * `react-native`, as the preview resolves it.
 *
 * The preview has always aliased `react-native` to `react-native-web`; this
 * module is that alias, with two hooks replaced. Both answer questions about
 * the environment, and in a browser both answer about the *browser* — which is
 * not the environment the screen being reviewed is in.
 *
 * `useWindowDimensions` decides between the phone stack and the iPad split
 * view, so left alone the preview would draw an iPad layout inside a phone
 * frame on any wide display: a layout the app never has. `useColorScheme`
 * decides light or dark, so left alone whether a screen matched
 * `01-parent-home.png` or `14-parent-home-dark.png` would depend on the
 * reviewer's laptop.
 *
 * Everything else is react-native-web untouched. This is the only place the
 * preview differs from what the device runs, and it exists so that the frame
 * the browser draws is the frame the screen measures.
 */
export * from 'react-native-web';

export function useWindowDimensions(): ScaledSize {
  // Both hooks run every render, in the same order, whichever one answers.
  const browser = useBrowserWindowDimensions();
  const device = useDeviceViewport();
  return device ?? browser;
}

export function useColorScheme(): ColorSchemeName | null {
  const browser = useBrowserColorScheme();
  const preview = usePreviewScheme();
  return preview ?? browser;
}
