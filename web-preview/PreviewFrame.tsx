import React from 'react';

/**
 * The chrome around the preview.
 *
 * Two jobs. It puts the app in a phone-shaped viewport so the layout is judged
 * at the size it was designed for, and it says plainly what this page is — a
 * browser rendering of the React Native UI, with no Screen Time behind it.
 * Without that banner the preview would be easy to mistake for the shipping
 * app, which is the one thing it must never be taken for.
 */
export function PreviewFrame({ children }: { children: React.ReactNode }): React.ReactElement {
  return (
    <div style={styles.page}>
      <header style={styles.header}>
        <div style={styles.title}>HopPotty — React Native preview</div>
        <div style={styles.subtitle}>
          The real RN components, rendered in a browser through react-native-web. Screen Time,
          StoreKit and notifications are iOS-native and are <strong>not</strong> present here —
          this is a UI preview, not the app.
        </div>
      </header>

      <div style={styles.deviceWrap}>
        <div style={styles.device}>
          <div style={styles.screen}>{children}</div>
        </div>
      </div>

      <footer style={styles.footer}>
        Generated from the app&apos;s own Swift design tokens and art rig — 4 appearances, 24
        semantic colours, 16 type styles, and 15 mascot poses verified element-for-element against
        the rig.
      </footer>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  page: {
    minHeight: '100%',
    background: 'linear-gradient(180deg, #EEF3F6 0%, #E4EDF2 100%)',
    fontFamily:
      '-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif',
    color: '#2A3742',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    padding: '28px 16px 40px',
    boxSizing: 'border-box',
  },
  header: { maxWidth: 620, textAlign: 'center', marginBottom: 22 },
  title: { fontSize: 26, fontWeight: 800, letterSpacing: -0.4 },
  subtitle: { fontSize: 14.5, lineHeight: 1.5, color: '#5A6B7A', marginTop: 8 },
  deviceWrap: { display: 'flex', justifyContent: 'center' },
  device: {
    width: 393,
    height: 852,
    maxHeight: '80vh',
    borderRadius: 46,
    background: '#11181F',
    padding: 10,
    boxShadow: '0 24px 60px rgba(20,40,60,.28)',
  },
  screen: {
    width: '100%',
    height: '100%',
    borderRadius: 38,
    overflow: 'hidden',
    background: '#FFF9F2',
    display: 'flex',
    flexDirection: 'column',
  },
  footer: { maxWidth: 620, textAlign: 'center', fontSize: 12.5, color: '#7A8896', marginTop: 22 },
};
