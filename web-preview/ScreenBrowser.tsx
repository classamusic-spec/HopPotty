import React, { useMemo, useState } from 'react';

import { DEVICE_FRAME } from './DeviceViewport';

/**
 * A browser for every screen in the app.
 *
 * The migration's hardest problem in this environment is that nobody can *see*
 * it: the React Native app needs a Mac to build, so a screen is otherwise a
 * diff. This lists every ported screen down one side and renders the selected
 * one at true device size, which is what makes visual QA against
 * `Art/render/screens/` possible at all.
 *
 * It is a review surface, not the app's navigation — the real router is
 * `src/navigation/`. Screens appear here as isolated presentational components
 * with fixture data, which is exactly how they are written.
 */

export interface ScreenEntry {
  id: string;
  /** How it appears in the list. */
  label: string;
  /** The design render this screen is a port of, if it has one. */
  render?: string;
  /** iPad screens are shown in a landscape frame. */
  device?: 'phone' | 'ipad';
  element: React.ReactNode;
}

export interface ScreenGroup {
  title: string;
  tint: string;
  screens: ScreenEntry[];
}

// The same frames the screens themselves are told they are running in, so the
// box the browser draws and the size a layout measures cannot drift apart.
const PHONE = DEVICE_FRAME.phone;
const IPAD = DEVICE_FRAME.ipad;

export function ScreenBrowser({ groups }: { groups: ScreenGroup[] }): React.ReactElement {
  const flat = useMemo(() => groups.flatMap((g) => g.screens), [groups]);
  const [selected, setSelected] = useState<string>(flat[0]?.id ?? '');
  const current = flat.find((s) => s.id === selected) ?? flat[0];
  const device = current?.device === 'ipad' ? IPAD : PHONE;
  const total = flat.length;

  return (
    <div style={S.page}>
      <aside style={S.rail}>
        <div style={S.brand}>
          <div style={S.brandTitle}>HopPotty</div>
          <div style={S.brandSub}>React Native · {total} screens</div>
        </div>

        {groups.map((group) => (
          <div key={group.title} style={S.group}>
            <div style={S.groupTitle}>
              <span style={{ ...S.dot, background: group.tint }} />
              {group.title}
              <span style={S.groupCount}>{group.screens.length}</span>
            </div>
            {group.screens.map((s) => {
              const active = s.id === selected;
              return (
                <button
                  key={s.id}
                  onClick={() => setSelected(s.id)}
                  style={{
                    ...S.item,
                    ...(active ? S.itemActive : null),
                    borderLeftColor: active ? group.tint : 'transparent',
                  }}
                >
                  <span style={S.itemLabel}>{s.label}</span>
                  {s.render ? <span style={S.itemRender}>{s.render}</span> : null}
                </button>
              );
            })}
          </div>
        ))}
      </aside>

      <main style={S.stage}>
        <header style={S.header}>
          <div style={S.headerTitle}>{current?.label}</div>
          <div style={S.headerNote}>
            {current?.render
              ? `ported from ${current.render}`
              : 'no design render — designed in-style'}
            {' · '}
            {current?.device === 'ipad' ? '1024×768' : '393×852'}
          </div>
        </header>

        <div style={S.deviceWrap}>
          <div
            style={{
              ...S.device,
              width: device.width + 20,
              height: device.height + 20,
              borderRadius: current?.device === 'ipad' ? 30 : 46,
            }}
          >
            <div
              style={{
                ...S.screen,
                width: device.width,
                height: device.height,
                borderRadius: current?.device === 'ipad' ? 20 : 38,
              }}
            >
              {current?.element}
            </div>
          </div>
        </div>

        <footer style={S.footer}>
          A browser rendering of the React Native UI through react-native-web.
          Screen Time, StoreKit and notifications are iOS-native and are <b>not</b> present —
          this is a UI preview, not the app.
        </footer>
      </main>
    </div>
  );
}

const S: Record<string, React.CSSProperties> = {
  page: {
    display: 'flex',
    minHeight: '100vh',
    background: '#EEF3F6',
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif',
    color: '#2A3742',
  },
  rail: {
    width: 268,
    flexShrink: 0,
    background: '#FFFFFF',
    borderRight: '1px solid #DCE5EB',
    padding: '18px 0 40px',
    overflowY: 'auto',
    maxHeight: '100vh',
    position: 'sticky',
    top: 0,
  },
  brand: { padding: '0 18px 14px' },
  brandTitle: { fontSize: 19, fontWeight: 800, letterSpacing: -0.3 },
  brandSub: { fontSize: 12, color: '#7A8896', marginTop: 2 },
  group: { marginTop: 14 },
  groupTitle: {
    display: 'flex',
    alignItems: 'center',
    gap: 7,
    padding: '0 18px 6px',
    fontSize: 11,
    fontWeight: 700,
    textTransform: 'uppercase',
    letterSpacing: 0.6,
    color: '#8494A2',
  },
  groupCount: { marginLeft: 'auto', fontWeight: 600, color: '#AAB6C1' },
  dot: { width: 8, height: 8, borderRadius: 4, display: 'inline-block' },
  item: {
    display: 'block',
    width: '100%',
    textAlign: 'left',
    background: 'none',
    border: 'none',
    borderLeft: '3px solid transparent',
    padding: '6px 18px',
    cursor: 'pointer',
    font: 'inherit',
  },
  itemActive: { background: '#F1F6F9' },
  itemLabel: { display: 'block', fontSize: 13.5, fontWeight: 600 },
  itemRender: { display: 'block', fontSize: 11, color: '#98A6B2', marginTop: 1 },
  stage: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    padding: '26px 20px 40px',
  },
  header: { textAlign: 'center', marginBottom: 18 },
  headerTitle: { fontSize: 22, fontWeight: 800, letterSpacing: -0.3 },
  headerNote: { fontSize: 12.5, color: '#7A8896', marginTop: 4 },
  deviceWrap: { display: 'flex', justifyContent: 'center' },
  device: { background: '#11181F', padding: 10, boxShadow: '0 24px 60px rgba(20,40,60,.26)' },
  screen: { overflow: 'hidden', background: '#FFF9F2', display: 'flex', flexDirection: 'column' },
  footer: { maxWidth: 560, textAlign: 'center', fontSize: 12, color: '#8494A2', marginTop: 22 },
};
