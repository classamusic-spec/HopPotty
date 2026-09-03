/**
 * GENERATED FILE — DO NOT EDIT.
 *
 * Source of truth: HopPottyKit/Sources/HopPottyDesignTokens (Swift),
 * exported by the `hoptokens` executable to Scripts/tokens.json.
 *
 * Regenerate:  node Scripts/rn/build-tokens.js
 * Verify:      node Scripts/rn/build-tokens.js --check
 */

export type HopAppearance = "dark" | "darkHighContrast" | "light" | "lightHighContrast";

export interface HopSemanticColors {
  readonly backgroundPrimary: string;
  readonly backgroundSecondary: string;
  readonly brandAction: string;
  readonly brandPrimary: string;
  readonly brandSecondary: string;
  readonly celebration: string;
  readonly divider: string;
  readonly eventAccident: string;
  readonly eventPee: string;
  readonly eventPoop: string;
  readonly eventTried: string;
  readonly focusRing: string;
  readonly neutral: string;
  readonly scrim: string;
  readonly shadow: string;
  readonly success: string;
  readonly surface: string;
  readonly surfaceElevated: string;
  readonly surfaceSunken: string;
  readonly textOnBrand: string;
  readonly textPrimary: string;
  readonly textSecondary: string;
  readonly textTertiary: string;
  readonly warning: string;
}

export const appearances: Readonly<Record<HopAppearance, HopSemanticColors>> = {
  dark: {
    backgroundPrimary: "#14192A",
    backgroundSecondary: "#1B2337",
    brandAction: "#8FDCAC",
    brandPrimary: "#8FDCAC",
    brandSecondary: "#9BDCF1",
    celebration: "#FFD769",
    divider: "#33415C",
    eventAccident: "#9AA3B4",
    eventPee: "#9BDCF1",
    eventPoop: "#FFB3A3",
    eventTried: "#C3BAFA",
    focusRing: "#7CC4F0",
    neutral: "#8B94A6",
    scrim: "#000000",
    shadow: "#000000",
    success: "#8FDCAC",
    surface: "#1B2337",
    surfaceElevated: "#243047",
    surfaceSunken: "#0E1220",
    textOnBrand: "#14192A",
    textPrimary: "#F3F1ED",
    textSecondary: "#B4BCCB",
    textTertiary: "#8B94A6",
    warning: "#FFD769",
  },
  darkHighContrast: {
    backgroundPrimary: "#000000",
    backgroundSecondary: "#0E1220",
    brandAction: "#A8E8C2",
    brandPrimary: "#A8E8C2",
    brandSecondary: "#B0E4F7",
    celebration: "#FFE49A",
    divider: "#5A6780",
    eventAccident: "#C3CAD8",
    eventPee: "#B0E4F7",
    eventPoop: "#FFC8BB",
    eventTried: "#D5CFFF",
    focusRing: "#A5D8F7",
    neutral: "#B4BCCB",
    scrim: "#000000",
    shadow: "#000000",
    success: "#A8E8C2",
    surface: "#11172A",
    surfaceElevated: "#1B2337",
    surfaceSunken: "#000000",
    textOnBrand: "#000000",
    textPrimary: "#FFFFFF",
    textSecondary: "#D7DDE8",
    textTertiary: "#B4BCCB",
    warning: "#FFE49A",
  },
  light: {
    backgroundPrimary: "#FFF9F2",
    backgroundSecondary: "#F7F1E9",
    brandAction: "#256F46",
    brandPrimary: "#63C88A",
    brandSecondary: "#6FC7E8",
    celebration: "#A87A0C",
    divider: "#EBE3D8",
    eventAccident: "#7D766D",
    eventPee: "#2A87AC",
    eventPoop: "#C96755",
    eventTried: "#6F63C0",
    focusRing: "#1C6FA8",
    neutral: "#7D766D",
    scrim: "#14192A",
    shadow: "#243047",
    success: "#2F8C57",
    surface: "#FFFFFF",
    surfaceElevated: "#FFFFFF",
    surfaceSunken: "#F7F1E9",
    textOnBrand: "#FFFFFF",
    textPrimary: "#243047",
    textSecondary: "#5A544D",
    textTertiary: "#7D766D",
    warning: "#A87A0C",
  },
  lightHighContrast: {
    backgroundPrimary: "#FFFFFF",
    backgroundSecondary: "#FFFCF8",
    brandAction: "#1B5E39",
    brandPrimary: "#2F8C57",
    brandSecondary: "#2A87AC",
    celebration: "#7A5A08",
    divider: "#AFA69B",
    eventAccident: "#5A544D",
    eventPee: "#15566F",
    eventPoop: "#8A3F30",
    eventTried: "#453B85",
    focusRing: "#0B4E7C",
    neutral: "#5A544D",
    scrim: "#14192A",
    shadow: "#14192A",
    success: "#1B5E39",
    surface: "#FFFFFF",
    surfaceElevated: "#FFFFFF",
    surfaceSunken: "#F7F1E9",
    textOnBrand: "#FFFFFF",
    textPrimary: "#14192A",
    textSecondary: "#413B34",
    textTertiary: "#4F4840",
    warning: "#7A5A08",
  },
};

export const palette = {
  cloud: "#FFF9F2",
  hopGreen: "#63C88A",
  hopGreenDeep: "#2F8C57",
  hopGreenInk: "#1B5E39",
  hopGreenLight: "#8FDCAC",
  hopGreenSoft: "#E3F5EA",
  lavender: "#AFA5EF",
  lavenderDeep: "#6F63C0",
  lavenderSoft: "#EFEDFB",
  midnight: "#243047",
  peachDeep: "#C96755",
  peachPop: "#FF9F8F",
  peachSoft: "#FFE8E3",
  pondBlue: "#6FC7E8",
  pondBlueDeep: "#2A87AC",
  pondBlueLight: "#9BDCF1",
  pondBlueSoft: "#E0F4FC",
  sand100: "#F7F1E9",
  sand200: "#EBE3D8",
  sand300: "#D8CEC1",
  sand500: "#7D766D",
  sand600: "#5A544D",
  sunshine: "#FFD769",
  sunshineBright: "#FFC53D",
  sunshineDeep: "#A87A0C",
  sunshineSoft: "#FFF3D4",
} as const;

export type HopPaletteName = keyof typeof palette;

/** Layout rhythm, in points. */
export const spacing = {
  giant: 56,
  huge: 40,
  l: 16,
  m: 12,
  pageCompact: 20,
  pageRegular: 32,
  s: 8,
  xl: 20,
  xs: 4,
  xxl: 24,
  xxs: 2,
  xxxl: 32,
} as const;

/** Corner radii, in points. */
export const radius = {
  hero: 44,
  l: 20,
  m: 14,
  s: 10,
  xl: 26,
  xs: 6,
  xxl: 34,
} as const;

/** Minimum touch targets. `child*` values are deliberately large. */
export const hitTarget = {
  childMinimum: 72,
  childPrimary: 96,
  parentMinimum: 44,
} as const;

export interface HopTypeStyle {
  readonly family: string;
  readonly size: number;
  readonly weight: string;
  readonly lineHeight: number;
  readonly tracking: number;
  /** Whether this style participates in Dynamic Type scaling. */
  readonly scales: boolean;
}

export const typography = {
  buttonLarge: { family: "rounded", size: 22, weight: "bold", lineHeight: 1.15, tracking: 0, scales: true },
  celebration: { family: "rounded", size: 38, weight: "heavy", lineHeight: 1.1, tracking: -0.6, scales: true },
  childInstruction: { family: "rounded", size: 24, weight: "semibold", lineHeight: 1.28, tracking: 0, scales: true },
  childTitle: { family: "rounded", size: 34, weight: "bold", lineHeight: 1.14, tracking: -0.4, scales: true },
  hero: { family: "rounded", size: 44, weight: "heavy", lineHeight: 1.08, tracking: -0.8, scales: true },
  metric: { family: "rounded", size: 28, weight: "bold", lineHeight: 1.1, tracking: -0.3, scales: true },
  parentBody: { family: "standard", size: 17, weight: "regular", lineHeight: 1.35, tracking: 0, scales: true },
  parentCallout: { family: "standard", size: 15, weight: "regular", lineHeight: 1.33, tracking: 0, scales: true },
  parentCaption: { family: "standard", size: 13, weight: "regular", lineHeight: 1.31, tracking: 0, scales: true },
  parentFootnote: { family: "standard", size: 12, weight: "medium", lineHeight: 1.33, tracking: 0.2, scales: true },
  parentHeadline: { family: "standard", size: 17, weight: "semibold", lineHeight: 1.29, tracking: 0, scales: true },
  parentLargeTitle: { family: "standard", size: 32, weight: "bold", lineHeight: 1.14, tracking: -0.5, scales: true },
  parentMetric: { family: "standard", size: 24, weight: "bold", lineHeight: 1.15, tracking: -0.4, scales: true },
  parentTitle: { family: "rounded", size: 22, weight: "semibold", lineHeight: 1.2, tracking: -0.2, scales: true },
  timer: { family: "standard", size: 56, weight: "bold", lineHeight: 1, tracking: -1.4, scales: true },
  timerHero: { family: "standard", size: 72, weight: "heavy", lineHeight: 1, tracking: -2, scales: false },
} as const satisfies Readonly<Record<string, HopTypeStyle>>;

export type HopTypeStyleName = keyof typeof typography;

export interface HopMotionSpec {
  /** Seconds. */
  readonly duration: number;
  /** SwiftUI spring bounce, 0 = critically damped. */
  readonly bounce: number;
}

export const motion = {
  childArrive: { duration: 0.55, bounce: 0.28 },
  childCelebrate: { duration: 0.7, bounce: 0.42 },
  childTap: { duration: 0.3, bounce: 0.34 },
  parentTap: { duration: 0.22, bounce: 0.1 },
  parentTransition: { duration: 0.34, bounce: 0 },
} as const satisfies Readonly<Record<string, HopMotionSpec>>;

export type HopMotionName = keyof typeof motion;
