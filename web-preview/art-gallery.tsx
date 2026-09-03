/**
 * Every illustration the app can draw, on one page.
 *
 * A developer surface, not a product screen. `react-native-svg` does not
 * support the whole SVG feature set, so a gradient it silently ignores or a
 * clip path it drops would otherwise be discovered one screen at a time, long
 * after the art was generated. Here it is one glance.
 */
import React from 'react';
import { createRoot } from 'react-dom/client';
import { View } from 'react-native';
import { HopArtwork } from '../src/art/HopArtwork';
import { HOP_ARTWORK, type HopIllustrationKey } from '../src/art/artwork.generated';

const keys = Object.keys(HOP_ARTWORK) as HopIllustrationKey[];
function Gallery() {
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, padding: 12, background: '#EEF3F6' }}>
      {keys.map((k) => (
        <div key={k} style={{ width: 150, textAlign: 'center', fontSize: 9, fontFamily: 'system-ui' }}>
          <View style={{ width: 150, height: 112, backgroundColor: '#fff', borderRadius: 8, overflow: 'hidden' }}>
            <HopArtwork artwork={k} fit="contain" decorative style={{ flex: 1 }} />
          </View>
          <div style={{ color: '#556' }}>{k}</div>
        </div>
      ))}
    </div>
  );
}
createRoot(document.getElementById('root')!).render(<Gallery />);
