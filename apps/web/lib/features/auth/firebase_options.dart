import 'package:firebase_core/firebase_core.dart';

/// Public Firebase web app identifiers, not an administrative credential.
const paylogFirebaseWebOptions = FirebaseOptions(
  apiKey: 'AIzaSyD4buMldb4jQebj_schvKwxEeKinR4OmwY',
  authDomain: 'paylog-c5c2d.firebaseapp.com',
  projectId: 'paylog-c5c2d',
  storageBucket: 'paylog-c5c2d.firebasestorage.app',
  messagingSenderId: '438590959896',
  appId: '1:438590959896:web:618667aa5bf1292a1d6e6d',
);

/// Compile-time local testing only; production builds leave this false and
/// emulator builds are written to a separate output directory.
const useFirebaseEmulators = bool.fromEnvironment('PAYLOG_USE_EMULATORS');
const activeFirebaseOptions = useFirebaseEmulators
    ? FirebaseOptions(
        apiKey: 'fake-api-key',
        authDomain: 'localhost',
        projectId: 'demo-paylog',
        messagingSenderId: '1234567890',
        appId: '1:1234567890:web:local-emulator',
      )
    : paylogFirebaseWebOptions;
