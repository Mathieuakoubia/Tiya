import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web not configured.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDY1T1UCAzl6ayiySBjsJz1bXL0ouGdR7U',
    appId: '1:493252079128:android:646276f5d2a0e5bb2f9d6d',
    messagingSenderId: '493252079128',
    projectId: 'tiyia-481310',
    storageBucket: 'tiyia-481310.firebasestorage.app',
  );
}
