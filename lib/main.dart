import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gMail;

import 'package:firebase_core/firebase_core.dart';

import 'package:audioplayers/audioplayers.dart';

import 'package:flutter_tts/flutter_tts.dart';

import 'google_sign_in.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Email Playlist App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

enum TtsState { playing, stopped, paused, continued }

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<gMail.Message> playlist = [];
  int currentPlayingMessageIndex = 0;

  // TTS
  late FlutterTts flutterTts;
  String? language;
  String? engine;
  double volume = 0.5;
  double pitch = 1.0;
  double rate = 0.5;
  bool isCurrentLanguageInstalled = false;
  int end = 0;

  TtsState ttsState = TtsState.stopped;

  bool get isPlaying => ttsState == TtsState.playing;
  bool get isStopped => ttsState == TtsState.stopped;
  bool get isPaused => ttsState == TtsState.paused;
  bool get isContinued => ttsState == TtsState.continued;

  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isWindows => !kIsWeb && Platform.isWindows;
  bool get isWeb => kIsWeb;

  @override
  initState() {
    super.initState();
    initTts();
    _handleSignIn();
  }

  dynamic initTts() {
    flutterTts = FlutterTts();

    _setAwaitOptions();

    if (isAndroid) {
      _getDefaultEngine();
      _getDefaultVoice();
    }

    flutterTts.setStartHandler(() {
      setState(() {
        print("Playing");
        ttsState = TtsState.playing;
      });
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        print("Complete");
        ttsState = TtsState.stopped;
      });
    });

    flutterTts.setCancelHandler(() {
      setState(() {
        print("Cancel");
        ttsState = TtsState.stopped;
      });
    });

    flutterTts.setPauseHandler(() {
      setState(() {
        print("Paused");
        ttsState = TtsState.paused;
      });
    });

    flutterTts.setContinueHandler(() {
      setState(() {
        print("Continued");
        ttsState = TtsState.continued;
      });
    });

    flutterTts.setErrorHandler((msg) {
      setState(() {
        print("error: $msg");
        ttsState = TtsState.stopped;
      });
    });

    flutterTts.setProgressHandler(
        (String text, int startOffset, int endOffset, String word) {
      setState(() {
        end = endOffset;
      });
    });
  }

  Future<dynamic> _getLanguages() async => await flutterTts.getLanguages;

  Future<dynamic> _getEngines() async => await flutterTts.getEngines;

  Future<void> _getDefaultEngine() async {
    var engine = await flutterTts.getDefaultEngine;
    if (engine != null) {
      print(engine);
    }
  }

  Future<void> _getDefaultVoice() async {
    var voice = await flutterTts.getDefaultVoice;
    if (voice != null) {
      print(voice);
    }
  }

  Future<void> _continue() async {
    _playPlaylist(currentPlayingMessageIndex);
  }

  Future<void> _playPlaylist(int playlistIndex) async {
    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);

    for (var i = playlistIndex; i < playlistIndex + playlist.length; i++) {
      // if overflow, start from the beginning till everything is read
      int index = (i < playlist.length) ? i : (i - playlist.length);

      setState(() {
        currentPlayingMessageIndex = index;
      });

      if (playlist[index].snippet == null) {
        continue;
      }

      await flutterTts.speak(playlist[index].snippet!);

      if (isStopped || isPaused) {
        break;
      }
    }
  }

  Future<void> _setAwaitOptions() async {
    await flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> _stop() async {
    var result = await flutterTts.stop();
    if (result == 1) setState(() => ttsState = TtsState.stopped);
  }

  Future<void> _pause() async {
    var result = await flutterTts.pause();
    if (result == 1) setState(() => ttsState = TtsState.paused);
  }

  @override
  void dispose() {
    super.dispose();
    flutterTts.stop();
  }

  // Sign in with Google
  Future<void> _handleSignIn() async {
    debugPrint('Sign in with Google');
    try {
      final GoogleSignInAccount? googleUser =
          await GoogleSignInProvider().ensureLoggedInOnStartUp();
      if (googleUser == null) {
        // The user canceled the sign-in
        debugPrint('Sign in canceled');
        return;
      }

      debugPrint('User signed in');
      print(googleUser);

      final authClient = GoogleAuthClient(await googleUser.authHeaders);
      final gmailApi = gMail.GmailApi(authClient);

      // Fetch emails
      final messages = await gmailApi.users.messages.list('me');
      if (messages.messages == null) return;
      debugPrint("number of messages: ${messages.messages!.length}");
      for (var message in messages.messages!) {
        final msg = await gmailApi.users.messages
            .get('me', message.id!, format: 'full');
        playlist.add(msg);
      }

      setState(() {});
    } catch (error) {
      print(error);
    }
  }

  void _mailSelected(int index) {
    if (isPlaying) {
      if (currentPlayingMessageIndex == index) {
        // ignore if the same message is selected
      } else {
        _stop();
        _playPlaylist(index);
      }
    } else if (isPaused) {
      if (currentPlayingMessageIndex == index) {
        _continue();
      } else {
        _stop();
        _playPlaylist(index);
      }
    } else {
      _playPlaylist(index);
    }
  }

  // Widgets ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Playlist App'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _handleSignIn,
            child: const Text('Sign in with Google'),
          ),
          Expanded(
            child: Scrollbar(
              child: ListView.builder(
                itemCount: playlist.length,
                itemBuilder: (context, index) {
                  return _mailTile(index);
                },
              ),
            ),
          ),
          _progressBar(end),
        ],
      ),
    );
  }

  Widget _mailTile(int index) {
    return ListTile(
        title: Text(
          getMailTitle(playlist[index]),
          style: TextStyle(
              fontSize: 18.0,
              color: ((isPlaying && (index == currentPlayingMessageIndex))
                  ? Colors.blue
                  : Colors.black)),
        ),
        subtitle: Text(playlist[index].snippet ?? ''),
        // trailing: _playPauseButton(index),
        onTap: () => _mailSelected(index), // Placeholder: use real URLs
        shape: const Border(
          bottom: BorderSide(color: Colors.grey),
        ));
  }

  Widget _progressBar(int end) {
    if (playlist.isEmpty) {
      return Container();
    } else if (playlist[currentPlayingMessageIndex].snippet == null) {
      return Container();
    }
    return Container(
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 25.0, left: 25.0, right: 25.0),
        child: LinearProgressIndicator(
          value: end / playlist[currentPlayingMessageIndex].snippet!.length,
        ));
  }
}

// Helper functions --------------------------------------------------------
String getMailTitle(gMail.Message message) {
  final headers = message.payload?.headers;
  if (headers == null) {
    return 'No title';
  }
  final subject = headers.firstWhere(
    (header) => header.name == 'Subject',
    orElse: () => gMail.MessagePartHeader(name: 'Subject', value: 'No title'),
  );
  return subject.value ?? 'No title';
}
