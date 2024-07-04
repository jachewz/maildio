import 'package:flutter/material.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gMail;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:audioplayers/audioplayers.dart';

import 'google_sign_in.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Email Playlist App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<gMail.Message> messagesList = [];
  List<String> playlist = [];

  Future<void> _handleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser =
          await GoogleSignInProvider().ensureLoggedInOnStartUp();
      if (googleUser == null) {
        // The user canceled the sign-in
        return;
      }

      final authClient = await GoogleAuthClient(await googleUser.authHeaders);
      final gmailApi = gMail.GmailApi(authClient);

      // Fetch emails
      final messages = await gmailApi.users.messages.list('me');
      if (messages.messages == null) return;
      for (var message in messages.messages!) {
        final msg = await gmailApi.users.messages.get('me', message.id!);
        final snippet = msg.snippet ?? '';
        if (snippet.contains('music')) {
          playlist.add(snippet); // Simplified: add snippet to playlist
        }
      }

      setState(() {});
    } catch (error) {
      print(error);
    }
  }

  void _playAudio(String url) {
    final player = AudioPlayer();
    player.play(UrlSource(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Email Playlist App'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _handleSignIn,
            child: Text('Sign in with Google'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: playlist.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(playlist[index]),
                  onTap: () =>
                      _playAudio(playlist[index]), // Placeholder: use real URLs
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
