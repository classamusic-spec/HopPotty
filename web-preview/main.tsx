import React from 'react';
import { createRoot } from 'react-dom/client';
import { AppRegistry } from 'react-native';

import { App } from '../src/app/App';
import { PreviewFrame } from './PreviewFrame';

AppRegistry.registerComponent('HopPotty', () => App);

const container = document.getElementById('root');
if (!container) throw new Error('no #root');
createRoot(container).render(
  <React.StrictMode>
    <PreviewFrame>
      <App />
    </PreviewFrame>
  </React.StrictMode>,
);
