import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

import 'package:loading_animation_widget/loading_animation_widget.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gMail;

import 'package:firebase_core/firebase_core.dart';

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
  // Google Sign In
  final GoogleSignInProvider _googleSignInProvider = GoogleSignInProvider();
  bool _loadingSignIn = false;
  List<String>? _selectedLabelIds;
  List<gMail.Label> _availableLabels = [];
  List<gMail.Message> playlist = [];
  int currentPlayingMessageIndex = 0;
  String currentPlayingMessageTitle = '';

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
        currentPlayingMessageTitle = getMailTitle(playlist[index]);
      });

      debugPrint('Playing message $index: $currentPlayingMessageTitle');

      if (playlist[index].snippet == null) {
        continue;
      }

      await flutterTts.speak(playlist[index].snippet!);

      if (isStopped || isPaused) {
        break;
      }
    }
  }

  Future<void> _playNext() async {
    if (currentPlayingMessageIndex < playlist.length - 1) {
      _playPlaylist(currentPlayingMessageIndex + 1);
    } else {
      _playPlaylist(0);
    }
  }

  Future<void> _playPrevious() async {
    if (currentPlayingMessageIndex > 0) {
      _playPlaylist(currentPlayingMessageIndex - 1);
    } else {
      _playPlaylist(playlist.length - 1);
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
  void _handleSignIn() async {
    debugPrint('Sign in with Google');
    setState(() {
      _loadingSignIn = true;
    });
    try {
      final GoogleSignInAccount? googleUser =
          await _googleSignInProvider.ensureLoggedInOnStartUp();
      if (googleUser == null) {
        // The user canceled the sign-in
        throw new Exception('User canceled the sign-in');
      }

      debugPrint('User signed in');
      print(googleUser);

      final authClient = GoogleAuthClient(await googleUser.authHeaders);
      final gmailApi = gMail.GmailApi(authClient);

      // Fetch categories
      final labels = await gmailApi.users.labels.list('me');
      _availableLabels = labels.labels ?? [];

      // print available labels

      print('Available labels: $_availableLabels');

      // Fetch emails
      final messages = await gmailApi.users.messages
          .list('me', labelIds: _selectedLabelIds, maxResults: 10);
      if (messages.messages != null) {
        debugPrint("number of messages: ${messages.messages!.length}");
        for (var message in messages.messages!) {
          debugPrint(message.id!);
          final msg = await gmailApi.users.messages
              .get('me', message.id!, format: 'full');
          playlist.add(msg);
        }
      } else {
        _clearPlaylist();
        debugPrint('No messages found');
      }

      setState(() {});
    } catch (error) {
      print(error);
    }

    setState(() {
      _loadingSignIn = false;
    });
  }

  void _clearPlaylist() {
    setState(() {
      playlist.clear();
      currentPlayingMessageIndex = 0;
      currentPlayingMessageTitle = '';
    });
  }

  Future<void> _refresh() async {
    _stop();
    _clearPlaylist();
    _handleSignIn();
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

  Future<void> _signOut() async {
    await _googleSignInProvider.signOutGoogle();
    setState(() {
      _clearPlaylist();
    });
  }

  // Widgets ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: _appBar(),
        drawer: _drawer(),
        body: Container(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _googleSignInProvider.user == null
                  ? [
                      ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _loadingSignIn = true;
                            });
                            _handleSignIn();
                            setState(() {});
                          },
                          child: const Text('Sign in with Google')),
                    ]
                  : _loadingSignIn
                      ? [
                          const Text('Loading emails...'),
                          const Padding(padding: EdgeInsets.all(10)),
                          LoadingAnimationWidget.beat(
                            size: 50,
                            color: Colors.blue,
                          ),
                        ]
                      : playlist.isEmpty
                          ? [
                              _refreshingCenter(),
                            ]
                          : [
                              // build if not empty playlist and signed in
                              Expanded(
                                child: RefreshIndicator(
                                  onRefresh: () {
                                    return _refresh();
                                  },
                                  child: Scrollbar(
                                    child: ListView.builder(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      itemCount: playlist.length,
                                      itemBuilder: (context, index) {
                                        return _mailTile(index);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              _controlsBar(),
                              _progressBar(end),
                            ],
            )),
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

  PreferredSizeWidget _appBar() {
    return AppBar(
      actions: [
        _labelsBar(),
      ],
    );
  }

  Widget _labelsBar() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        color: Colors.blue.withOpacity(0.1),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          scrollDirection: Axis.horizontal,
          itemCount: _availableLabels.length,
          itemBuilder: (context, index) {
            return _labelButton(index);
          },
        ),
      ),
    );
  }

  Widget _labelButton(int index) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: (_selectedLabelIds != null &&
                _selectedLabelIds!.contains(_availableLabels[index].id))
            ? Colors.blue
            : Colors.white,
      ),
      onPressed: () {
        setState(() {
          _selectedLabelIds = [_availableLabels[index].id!];
        });
        _handleSignIn();
      },
      child: Text(_availableLabels[index].name ?? ''),
    );
  }

  Widget _refreshingCenter() {
    return Expanded(
      child: RefreshIndicator(
        onRefresh: () {
          return _refresh();
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const []),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No emails found', textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlsBar() {
    if (playlist.isEmpty) {
      return Container();
    }
    return Container(
        color: Colors.blue.withOpacity(0.1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                iconSize: 30,
                onPressed: () => _playPrevious()),
            IconButton(
              icon: (isPlaying)
                  ? const Icon(Icons.pause_circle_filled)
                  : const Icon(Icons.play_circle_outline),
              iconSize: 50,
              onPressed: () => isPlaying
                  ? _pause()
                  : isPaused
                      ? _continue()
                      : _playPlaylist(0),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              iconSize: 30,
              onPressed: () => _playNext(),
            ),
          ],
        ));
  }

  Widget _progressBar(int end) {
    if (playlist.isEmpty) {
      return Container();
    } else if (playlist[currentPlayingMessageIndex].snippet == null) {
      return Container();
    }
    return Container(
        color: Colors.blue,
        alignment: Alignment.topCenter,
        child: LinearProgressIndicator(
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          value: end / playlist[currentPlayingMessageIndex].snippet!.length,
        ));
  }

  Widget? _drawer() {
    if (_googleSignInProvider.user == null) {
      return null;
    } else {
      return Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(_googleSignInProvider.user!.displayName ?? ''),
              accountEmail: Text(_googleSignInProvider.user!.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundImage:
                    NetworkImage(_googleSignInProvider.user!.photoURL ?? ''),
              ),
            ),
            ListTile(
              title: const Text('Sign out'),
              onTap: () => _signOut(),
            ),
          ],
        ),
      );
    }
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
