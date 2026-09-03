/**
 * react-native-web ships no types, and it is React Native's API by definition —
 * that is the whole promise of the package. So it is typed as React Native,
 * which also means the preview cannot quietly use something the device build
 * does not have.
 */
declare module 'react-native-web' {
  export * from 'react-native';
}
