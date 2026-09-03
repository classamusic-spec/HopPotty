import React from 'react';
import { Pressable, ScrollView, StyleSheet, View, useWindowDimensions } from 'react-native';
import Svg, { Path } from 'react-native-svg';

import { HopArtwork, type HopIllustrationKey } from '../../art/HopArtwork';
import { GrownUpButton, HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { HopCharacter } from '../../mascot/HopCharacter';
import { SpeakerGlyph } from '../child-hub/ChildGlyphs';

/**
 * One of Hop's questions.
 *
 * The reference is `Art/render/screens/12-quiz.png`. It is **audio-first**: Hop
 * asks the question out loud and the child answers with a picture. The written
 * question is there for a reader and for the caregiver sitting alongside — it
 * supports the sound, it does not replace it — and "Hear it again" is a
 * first-class control, the same size as anything else a child touches, because
 * a pre-reader who missed the question has no other way back to it.
 *
 * ## Nothing here counts
 *
 * There is no score, no timer, no streak and no "wrong". A pick that is not the
 * one being taught gets a warm invitation to try another and the answers stay
 * tappable underneath — which is why this screen reports the tap and holds no
 * opinion about it. Anything that ranked the answers would turn a conversation
 * with a frog into a test.
 */

/** One picture answer. The picture *is* the answer; the word supports it. */
export interface QuizAnswer {
  readonly id: string;
  readonly illustration: HopIllustrationKey;
  /**
   * The thing in the picture, named. Read aloud by VoiceOver straight after the
   * question, so it is written as a thing rather than as a sentence.
   */
  readonly label: string;
}

export interface QuizRoundScreenProps {
  /** The written form of what Hop just asked. */
  readonly question: string;
  /** Three or more pictures. Peers — nothing marks one as the answer. */
  readonly answers: readonly QuizAnswer[];
  readonly onAnswer: (id: string) => void;
  /** Says the question again. Never a penalty, never limited. */
  readonly onHearAgain: () => void;
  readonly onGrownUp?: () => void;
}

/**
 * The hues the answer cards cycle through.
 *
 * Peer differences, not grades: three kinds of thing in three colours, in a
 * fixed order, so the same question always looks the same and no colour ever
 * means "this one".
 */
const TINTS = ['peach', 'pondBlue', 'lavender'] as const;

export function QuizRoundScreen({
  question,
  answers,
  onAnswer,
  onHearAgain,
  onGrownUp,
}: QuizRoundScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const { width, height } = useWindowDimensions();
  const isWide = width >= 768;
  const domeHeight = Math.min(292, height * 0.35);

  return (
    <View style={[styles.root, { backgroundColor: theme.color.backgroundPrimary }]}>
      <Dome width={width} height={domeHeight} />

      <View
        style={[
          styles.content,
          {
            paddingHorizontal: theme.spacing.xxl,
            paddingBottom: theme.spacing.s,
            maxWidth: isWide ? 600 : undefined,
            alignSelf: isWide ? 'center' : 'stretch',
            width: isWide ? '100%' : undefined,
          },
        ]}
      >
        <View style={styles.grownUpRow}>
          {/* The way to a grown-up, in the same corner as every other child
              screen. The design render leaves this corner empty; the safety rule
              does not, and there is room for it without moving anything. */}
          <GrownUpButton onPress={onGrownUp} />
        </View>

        <View style={[styles.ask, { gap: theme.spacing.m }]}>
          <View
            style={[
              styles.avatar,
              { backgroundColor: theme.color.surface, borderRadius: AVATAR / 2 },
            ]}
          >
            {/* Hop, cropped to his face by the circle — the same drawing at the
                same product state, not a second portrait of him. */}
            <View style={styles.avatarInner} pointerEvents="none">
              <HopCharacter size={AVATAR_HOP} state="talk" decorative />
            </View>
          </View>

          <HopText variant="childInstruction" style={styles.question} accessibilityRole="header">
            {question}
          </HopText>
        </View>

        <View style={[styles.hearRow, { marginTop: theme.spacing.l }]}>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Hear it again"
            onPress={onHearAgain}
            style={({ pressed }) => [
              styles.hear,
              {
                minHeight: theme.hitTarget.childMinimum,
                borderRadius: theme.radius.hero,
                backgroundColor: theme.color.surface,
                paddingLeft: theme.spacing.xl,
                paddingRight: theme.spacing.xxl,
                gap: theme.spacing.m,
                opacity: pressed ? 0.85 : 1,
              },
            ]}
          >
            <SpeakerGlyph color={theme.palette.pondBlueDeep} size={26} />
            <HopText variant="parentTitle" tone="secondary">
              Hear it again
            </HopText>
          </Pressable>
        </View>

        <ScrollView
          style={styles.answers}
          contentContainerStyle={[
            styles.answerList,
            { gap: theme.spacing.l, paddingVertical: theme.spacing.xl },
          ]}
          showsVerticalScrollIndicator={false}
        >
          {answers.map((answer, i) => (
            <AnswerCard
              key={answer.id}
              answer={answer}
              tint={TINTS[i % TINTS.length] ?? 'peach'}
              onPress={() => onAnswer(answer.id)}
            />
          ))}
        </ScrollView>
      </View>
    </View>
  );
}

/** The avatar circle, and how large Hop is drawn inside it. */
const AVATAR = 62;
/**
 * Hop at this size puts his head, and only his head, in the circle.
 *
 * The rig's head sits at (0.5, 0.282) of its canvas and is 0.69 of it wide, so
 * a 92pt Hop offset by the values below lands his face centred in a 62pt hole.
 * Cropping the character is deliberate: there is one Hop, drawn from one rig,
 * and a separate face drawing here would be a second character to keep in sync.
 */
const AVATAR_HOP = 92;
const AVATAR_HEAD = { x: 0.5, y: 0.282 } as const;

/** One picture answer, drawn exactly like its peers. */
function AnswerCard({
  answer,
  tint,
  onPress,
}: {
  readonly answer: QuizAnswer;
  readonly tint: (typeof TINTS)[number];
  readonly onPress: () => void;
}): React.ReactElement {
  const theme = useHopTheme();

  const soft =
    tint === 'peach'
      ? theme.palette.peachSoft
      : tint === 'pondBlue'
        ? theme.palette.pondBlueSoft
        : theme.palette.lavenderSoft;
  const edge =
    tint === 'peach'
      ? theme.palette.peachPop
      : tint === 'pondBlue'
        ? theme.palette.pondBlueLight
        : theme.palette.lavender;

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={answer.label}
      onPress={onPress}
      style={({ pressed }) => [
        styles.card,
        {
          minHeight: 120,
          borderRadius: theme.radius.xxl,
          backgroundColor: theme.color.surface,
          borderColor: edge,
          paddingHorizontal: theme.spacing.xxl,
          gap: theme.spacing.xl,
          opacity: pressed ? 0.9 : 1,
        },
      ]}
    >
      <View style={[styles.picture, { backgroundColor: soft, borderRadius: theme.radius.xl }]}>
        <HopArtwork artwork={answer.illustration} width={76} height={76} decorative />
      </View>
      <HopText variant="metric" style={styles.cardLabel}>
        {answer.label}
      </HopText>
    </Pressable>
  );
}

/**
 * The green shoulder Hop asks from.
 *
 * A soft dome rather than a card: the question is a thing Hop is saying, and a
 * rounded rectangle around it would make it a form field.
 */
function Dome({ width, height }: { readonly width: number; readonly height: number }): React.ReactElement {
  const theme = useHopTheme();
  return (
    <Svg
      width={width}
      height={height + 12}
      pointerEvents="none"
      style={{ position: 'absolute', left: 0, top: 0 }}
    >
      <Path
        d={
          `M 0 0 H ${width} V ${height - 62} ` +
          `C ${width * 0.78} ${height + 10}, ${width * 0.22} ${height + 10}, 0 ${height - 62} Z`
        }
        fill={theme.palette.hopGreenSoft}
      />
    </Svg>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, overflow: 'hidden' },
  content: { flex: 1 },
  grownUpRow: { alignItems: 'flex-end', paddingTop: 4 },
  ask: { flexDirection: 'row', alignItems: 'flex-start' },
  avatar: { width: AVATAR, height: AVATAR, overflow: 'hidden' },
  avatarInner: {
    position: 'absolute',
    left: AVATAR / 2 - AVATAR_HOP * AVATAR_HEAD.x,
    top: AVATAR / 2 - AVATAR_HOP * AVATAR_HEAD.y,
    width: AVATAR_HOP,
    height: AVATAR_HOP,
  },
  question: { flex: 1 },
  hearRow: { alignItems: 'center' },
  hear: { flexDirection: 'row', alignItems: 'center' },
  answers: { flex: 1 },
  answerList: { justifyContent: 'center', flexGrow: 1 },
  card: { flexDirection: 'row', alignItems: 'center', borderWidth: 1.5 },
  picture: { width: 92, height: 92, alignItems: 'center', justifyContent: 'center' },
  cardLabel: { flex: 1 },
});
