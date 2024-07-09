import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gMail;
import 'package:http/http.dart' as http;

class GoogleSignInProvider {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      gMail.GmailApi.gmailReadonlyScope,
    ],
  );

  User? get user => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Future<void> signOutGoogle() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    print("User signed out");
  }

  Future<GoogleSignInAccount?> ensureLoggedInOnStartUp() async {
    // That class has a currentUser if there's already a user signed in on
    // this device.
    try {
      GoogleSignInAccount? googleSignInAccount = _googleSignIn.currentUser;
      if (googleSignInAccount == null) {
        // but if not, Google should try to sign one in whos previously signed in
        // on this phone.
        googleSignInAccount = await _googleSignIn.signIn();
        if (googleSignInAccount == null) {
          return null;
        }

        final GoogleSignInAuthentication googleSignInAuthentication =
            await googleSignInAccount.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleSignInAuthentication.accessToken,
          idToken: googleSignInAuthentication.idToken,
        );

        final UserCredential authResult =
            await _auth.signInWithCredential(credential);
        final User? user = authResult.user;

        if (user == null) {
          return null;
        }

        assert(!(user.isAnonymous));
        assert(await user.getIdToken() != null);

        final User? currentUser = _auth.currentUser;

        if (_auth.currentUser == null) {
          return null;
        }

        assert(user.uid == currentUser?.uid);

        return googleSignInAccount;
      } else {
        return googleSignInAccount;
      }
    } catch (e) {
      //on PlatformException
      print(e);
    }
    return null;
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;

  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
