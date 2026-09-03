import { useWindowDimensions as useBrowserWindowDimensions } from 'react-native-web';
import type { ScaledSize } from 'react-native-web';

import { useDeviceViewport } from './DeviceViewport';

/**
 * `react-native`, as the preview resolves it.
 *
 * The preview has always aliased `react-native` to `react-native-web`; this
 * module is that alias, with one hook replaced. `useWindowDimensions` in a
 * browser reports the browser window, and the screens use it to choose between
 * the phone stack and the iPad split view — so without this the preview would
 * draw an iPad layout inside a phone frame on any wide display, which is a
 * layout the app never has.
 *
 * Everything else is react-native-web untouched. This is the only place the
 * preview differs from what the device runs, and it exists so the frame the
 * browser draws and the size the screen measures are the same size.
 */
export * from 'react-native-web';

export function useWindowDimensions(): ScaledSize {
  // Both hooks run every render, in the same order, whichever one answers.
  const browser = useBrowserWindowDimensions();
  const device = useDeviceViewport();
  return device ?? browser;
}
