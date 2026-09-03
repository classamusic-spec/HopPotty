import React from 'react';
import { createRoot } from 'react-dom/client';
import { AppRegistry } from 'react-native';

import { App } from '../src/app/App';
import { ScreenBrowser } from './ScreenBrowser';
import { SCREEN_GROUPS } from './screens';

// The app still registers itself: this page is a review surface beside the app,
// not a replacement for it, and `AppRegistry` is how React Native is entered.
AppRegistry.registerComponent('HopPotty', () => App);

const container = document.getElementById('root');
if (!container) throw new Error('no #root');
createRoot(container).render(
  <React.StrictMode>
    <ScreenBrowser groups={SCREEN_GROUPS} />
  </React.StrictMode>,
);
