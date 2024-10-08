// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCU0xw5YqFWpPRz0Wt9tVoA8DJ1jTNqycU',
    appId: '1:628764696275:web:494fe26288269762d37e26',
    messagingSenderId: '628764696275',
    projectId: 'maildio',
    authDomain: 'maildio.firebaseapp.com',
    storageBucket: 'maildio.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBYfff1W_-9fdxSQPgDc9UE6Guie_EIX1Q',
    appId: '1:628764696275:android:fe5cafcdf3785ac8d37e26',
    messagingSenderId: '628764696275',
    projectId: 'maildio',
    storageBucket: 'maildio.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAxZLi6HSLXrfYnk9LMkws-SWOqfY8nbMw',
    appId: '1:628764696275:ios:892f1b07b6087096d37e26',
    messagingSenderId: '628764696275',
    projectId: 'maildio',
    storageBucket: 'maildio.appspot.com',
    iosBundleId: 'com.maildio.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAxZLi6HSLXrfYnk9LMkws-SWOqfY8nbMw',
    appId: '1:628764696275:ios:892f1b07b6087096d37e26',
    messagingSenderId: '628764696275',
    projectId: 'maildio',
    storageBucket: 'maildio.appspot.com',
    iosBundleId: 'com.maildio.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCU0xw5YqFWpPRz0Wt9tVoA8DJ1jTNqycU',
    appId: '1:628764696275:web:24193757f5a1b366d37e26',
    messagingSenderId: '628764696275',
    projectId: 'maildio',
    authDomain: 'maildio.firebaseapp.com',
    storageBucket: 'maildio.appspot.com',
  );
}
