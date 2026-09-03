/**
 * Translucency over a token colour.
 *
 * Not a licence to invent colours: every colour passed in comes from
 * `theme.color` or `theme.palette`, and the opacities are the ones the render
 * harness already uses (`Scripts/screens/ui.js`'s `alpha`). A scrim, a soft
 * plate under a caption and a dashed outline all need a colour at less than
 * full strength, and the design tokens carry no alpha channel.
 */
export function withAlpha(color: string, alpha: number): string {
  const hex = color.trim();
  if (!hex.startsWith('#') || (hex.length !== 7 && hex.length !== 4)) return hex;
  const full =
    hex.length === 4 ? `#${hex[1]}${hex[1]}${hex[2]}${hex[2]}${hex[3]}${hex[3]}` : hex;
  const r = parseInt(full.slice(1, 3), 16);
  const g = parseInt(full.slice(3, 5), 16);
  const b = parseInt(full.slice(5, 7), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}
