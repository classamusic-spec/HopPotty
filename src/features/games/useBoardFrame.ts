import { useCallback, useMemo, useState } from 'react';
import { useWindowDimensions, type LayoutChangeEvent } from 'react-native';

import { MAX_BOARD_WIDTH, sceneFrame, type SceneFrame } from './sceneFrame';

/**
 * The band, sized to the room the board actually has.
 *
 * `GameHost` gives the board whatever is left between the two lines of chrome
 * and the tray, and that is not the same on every game or on every device: a
 * board with a caption, a progress row and two buttons under it has a hundred
 * points less than one with a single button. Sizing the picture from the window
 * alone would let it run under the tray on a small phone, and stretch it past
 * the drawing's own resolution on iPad.
 *
 * So the band takes the smaller of "as wide as the board" and "as tall as the
 * board", and never grows past the scene's own width. The first frame uses the
 * window width and the measurement corrects it — the picture settles, it never
 * flashes at the wrong size, because both are the same on the phone layout the
 * renders were drawn at.
 */
export interface BoardFrame {
  frame: SceneFrame;
  /** Wire to the `flex: 1` view the band sits in. */
  onSlotLayout: (event: LayoutChangeEvent) => void;
}

export function useBoardFrame(heightRatio = 0.75): BoardFrame {
  const { width } = useWindowDimensions();
  const [slot, setSlot] = useState<{ width: number; height: number } | null>(null);

  const onSlotLayout = useCallback((event: LayoutChangeEvent) => {
    const { width: w, height: h } = event.nativeEvent.layout;
    setSlot((current) =>
      current && Math.abs(current.width - w) < 1 && Math.abs(current.height - h) < 1
        ? current
        : { width: w, height: h },
    );
  }, []);

  const frame = useMemo(() => {
    const across = Math.min(slot?.width ?? width, MAX_BOARD_WIDTH);
    const down = slot?.height ?? Number.POSITIVE_INFINITY;
    const bandWidth = across * heightRatio > down ? down / heightRatio : across;
    return sceneFrame(bandWidth, bandWidth * heightRatio);
  }, [slot, width, heightRatio]);

  return { frame, onSlotLayout };
}
