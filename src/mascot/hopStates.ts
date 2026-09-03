import type { HopPoseName } from './poses.generated';

/**
 * What Hop is doing, in product terms.
 *
 * Screens ask for a *state* — "reassure the child" — not for a rig pose. The
 * two vocabularies are deliberately separate: the rig's fifteen poses are
 * drawing positions owned by the art pipeline, while these are the moments the
 * product actually has. Several states share a pose, and that is fine; what
 * must not happen is a screen reaching past this map into pose names, because
 * then renaming a pose would break features rather than just this file.
 */
export type HopAnimationState =
  | 'idle'
  | 'blink'
  | 'look'
  | 'talk'
  | 'wave'
  | 'happy'
  | 'celebrate'
  | 'think'
  | 'reassure'
  | 'hop'
  | 'land'
  | 'sit'
  | 'sleep'
  | 'wash';

const POSE_FOR: Readonly<Record<HopAnimationState, HopPoseName>> = {
  idle: 'idle',
  blink: 'blink',
  // Gaze is the idle body with the pupils offset — the rig has no separate
  // looking pose, and inventing one would fork the character.
  look: 'idle',
  talk: 'talk',
  wave: 'wave',
  happy: 'cheer',
  celebrate: 'cheer',
  // Thinking reads as the waiting pose: weight settled, head up.
  think: 'wait',
  // Reassurance is deliberately the calmest pose in the set. A child being told
  // "it is alright" should not be met with a bouncing frog.
  reassure: 'idle',
  hop: 'jump',
  land: 'land',
  sit: 'sit',
  sleep: 'sleep',
  wash: 'scrub',
};

export function hopPoseFor(state: HopAnimationState): HopPoseName {
  return POSE_FOR[state];
}

/**
 * States that read correctly while motion is suppressed.
 *
 * Reduce Motion removes movement, not meaning: `celebrate` still shows the
 * cheering pose, it simply stops jumping. Only states whose whole content is
 * travel — `hop`, `land` — fall back to standing still.
 */
export function hopStateForReducedMotion(state: HopAnimationState): HopAnimationState {
  switch (state) {
    case 'hop':
    case 'land':
      return 'idle';
    default:
      return state;
  }
}
