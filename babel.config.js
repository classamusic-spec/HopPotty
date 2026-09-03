module.exports = {
  presets: ['@react-native/babel-preset'],
  plugins: [
    // Reanimated 4 runs its worklets through this plugin, and it must be last.
    // Without it `useAnimatedStyle` and friends need hand-written dependency
    // arrays, which is a silent-wrong-answer failure mode rather than an error.
    'react-native-worklets/plugin',
  ],
};
