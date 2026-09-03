import type React from 'react';
import { useCallback, useMemo, useRef } from 'react';
import { PanResponder, type GestureResponderHandlers, type View } from 'react-native';

import type { SceneFrame } from './sceneFrame';

/**
 * A finger moving across a board, reported in the scene's own coordinates.
 *
 * Two of these boards are rubbed rather than tapped — Mud Off and Bubble Wash —
 * and both need the same thing: where the finger *is*, continuously, so a patch
 * comes away when the child crosses it rather than when they let go.
 *
 * The responder is claimed on the **capture** phase, and only once the finger
 * has actually travelled. That ordering is the whole trick: a tap still reaches
 * the sprite underneath, which is a real button with a name and a role, so a
 * child who cannot yet drag — or who is using VoiceOver or Switch Control —
 * plays the same board rather than a described one.
 */
export interface SceneRub {
  ref: React.RefObject<React.ComponentRef<typeof View> | null>;
  panHandlers: GestureResponderHandlers;
  /** Re-measures where the board sits. Wire to the board's `onLayout`. */
  onLayout: () => void;
}

/** How far a finger travels before it is a rub rather than a tap, in points. */
const RUB_SLOP = 6;

export function useSceneRub(
  frame: SceneFrame,
  onPoint: (x: number, y: number) => void,
): SceneRub {
  // React Native 0.87 types `View` as a function component, so the instance
  // type — the thing that actually has `measureInWindow` — is its ComponentRef,
  // not `View` itself.
  const ref = useRef<React.ComponentRef<typeof View> | null>(null);
  const origin = useRef({ x: 0, y: 0 });

  // Kept in refs so the responder is created once: rebuilding it mid-gesture
  // would drop the touch the child is in the middle of.
  const latest = useRef({ frame, onPoint });
  latest.current = { frame, onPoint };

  const onLayout = useCallback(() => {
    ref.current?.measureInWindow((x, y) => {
      origin.current = { x, y };
    });
  }, []);

  const panHandlers = useMemo(() => {
    const report = (pageX: number, pageY: number) => {
      const { frame: f, onPoint: report_ } = latest.current;
      report_(
        f.sceneX(pageX - origin.current.x),
        f.sceneY(pageY - origin.current.y),
      );
    };
    return PanResponder.create({
      onStartShouldSetPanResponderCapture: () => false,
      onMoveShouldSetPanResponderCapture: (_e, g) =>
        Math.abs(g.dx) + Math.abs(g.dy) > RUB_SLOP,
      onPanResponderGrant: (e) => {
        onLayout();
        report(e.nativeEvent.pageX, e.nativeEvent.pageY);
      },
      onPanResponderMove: (_e, g) => report(g.moveX, g.moveY),
      onPanResponderTerminationRequest: () => false,
    }).panHandlers;
  }, [onLayout]);

  return { ref, panHandlers, onLayout };
}
