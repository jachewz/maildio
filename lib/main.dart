import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:html/parser.dart';

import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gMail;

import 'package:firebase_core/firebase_core.dart';

import 'package:flutter_tts/flutter_tts.dart';

import 'google_sign_in.dart';
import 'mail.dart';
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
  late MailProvider _mailProvider;

  bool _loadingSignIn = false;
  String _selectedLabel = 'INBOX';
  List<gMail.Label> _availableLabels = [];
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
  int ttsProgress = 0;
  int ttsPausedProgress = 0; // when paused ttsProgress gets wiped, so save it

  TtsState ttsState = TtsState.stopped;

  final PagingController<int, gMail.Message> _pagingController =
      PagingController(firstPageKey: 0);

  bool get isPlaying =>
      ttsState == TtsState.playing || ttsState == TtsState.continued;
  bool get isStopped => ttsState == TtsState.stopped;
  bool get isPaused => ttsState == TtsState.paused;
  bool get isContinued => ttsState == TtsState.continued;

  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isWindows => !kIsWeb && Platform.isWindows;
  bool get isWeb => kIsWeb;

  @override
  initState() {
    _handleSignIn().then((_) => _pagingController.refresh());
    super.initState();
    initTts();
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
    flutterTts.stop();
  }

  Future<void> _setTtsAwaitOptions() async {
    await flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> _getDefaultEngine() async {
    var engine = await flutterTts.getDefaultEngine;
    if (engine != null) {
      // print(engine);
    }
  }

  Future<void> _getDefaultVoice() async {
    var voice = await flutterTts.getDefaultVoice;
    if (voice != null) {
      // print(voice);
    }
  }

  dynamic initTts() {
    flutterTts = FlutterTts();

    _setTtsAwaitOptions();

    if (isAndroid) {
      _getDefaultEngine();
      _getDefaultVoice();
    }

    flutterTts.setStartHandler(() {
      setState(() {
        ttsPausedProgress = 0;
        ttsState = TtsState.playing;
      });
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        _playNext();
      });
    });

    flutterTts.setCancelHandler(() {
      setState(() {
        ttsState = TtsState.stopped;
      });
    });

    flutterTts.setPauseHandler(() {
      setState(() {
        ttsState = TtsState.paused;
        ttsPausedProgress += ttsProgress;
      });
    });

    flutterTts.setContinueHandler(() {
      setState(() {
        ttsState = TtsState.continued;
      });
    });

    flutterTts.setErrorHandler((msg) {
      setState(() {
        debugPrint("error: $msg");
        ttsState = TtsState.stopped;
      });
    });

    flutterTts.setProgressHandler(
        (String text, int startOffset, int endOffset, String word) {
      setState(() {
        ttsProgress = endOffset;
      });
    });
  }

  Future<void> _playPlaylist(int index) async {
    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);
    setState(() {
      currentPlayingMessageIndex = index;
    });

    String textToBeSpoken =
        '\nTitle: ${_mailProvider.getMailTitle(playlist[index])}';

    // read out sender
    final String sender = _mailProvider.getMailSender(playlist[index]);
    textToBeSpoken = '$textToBeSpoken \n Sent by: $sender';

    // read out body
    final String body = _mailProvider.getMailBody(playlist[index]);
    textToBeSpoken = '$textToBeSpoken \n Body: $body';

    if (index + 1 < playlist.length) {
      // if next message exists, say this before next message
      textToBeSpoken += '\n Next message: \n';
    }

    debugPrint(textToBeSpoken);
    flutterTts.speak(textToBeSpoken);
  }

  Future<void> _continue() async {
    _playPlaylist(currentPlayingMessageIndex);
  }

  Future<void> _startPlaying() async {
    _playPlaylist(0);
  }

  Future<void> _playButtonSelected() async {
    isPlaying
        ? _pause()
        : isPaused
            ? _continue()
            : _startPlaying();
  }

  Future<void> _playNext() async {
    _stop();
    if (currentPlayingMessageIndex < playlist.length - 1) {
      _playPlaylist(currentPlayingMessageIndex + 1);
    } else {
      _playPlaylist(playlist.length - 1);
    }
  }

  Future<void> _playPrevious() async {
    _stop();
    if (currentPlayingMessageIndex > 0) {
      _playPlaylist(currentPlayingMessageIndex - 1);
    } else {
      _playPlaylist(0);
    }
  }

  Future<void> _stop() async {
    var result = await flutterTts.stop();
    if (result == 1) setState(() => ttsState = TtsState.stopped);
  }

  Future<void> _pause() async {
    var result = await flutterTts.pause();
    if (result == 1) setState(() => ttsState = TtsState.paused);
  }

  // Sign in with Google
  Future _handleSignIn() async {
    debugPrint('Sign in with Google');

    setState(() {
      _loadingSignIn = true;
    });

    try {
      final GoogleSignInAccount? googleUser =
          await _googleSignInProvider.ensureLoggedInOnStartUp();
      if (googleUser == null) {
        // The user canceled the sign-in
        throw Exception('User canceled the sign-in');
      }

      debugPrint('User signed in $googleUser');

      final authClient = GoogleAuthClient(await googleUser.authHeaders);
      final gmailApi = gMail.GmailApi(authClient);

      _mailProvider = MailProvider(gmailApi);

      // after signing in, handle the new labels and mail
      _availableLabels = await _mailProvider.getLabels();
      debugPrint(_availableLabels[0].name);

      setState(() {});
    } catch (error) {
      debugPrint('Sign in error: $error');
    }

    setState(() {
      _loadingSignIn = false;
    });
  }

  void _clearPlaylist() {
    setState(() {
      playlist.clear();
      currentPlayingMessageIndex = 0;
    });
  }

  Future<void> _refresh() async {
    _pagingController.refresh();
  }

  void _mailSelected(gMail.Message message) {
    // get the index of the selected message
    int index =
        playlist.indexWhere((element) => element.hashCode == message.hashCode);

    if (isPlaying) {
        _stop();
      _playPlaylist(index);
    }
  }

  void _labelSelected(String labelId) {
    debugPrint('label id $labelId selected');
    _stop();
    setState(() {
      _selectedLabel = labelId;
    });
    _pagingController.refresh();
  }

  Future<void> _signOut() async {
    await _googleSignInProvider.signOutGoogle();
    setState(() {
      _clearPlaylist();
    });
  }

  void _addMessagesToPlaylist(List<gMail.Message> messages) {
    setState(() {
      // add unique messages to the playlist by looking at the hashcode
      for (var message in messages) {
        if (!playlist.any((element) => element.hashCode == message.hashCode)) {
          playlist.add(message);
        }
      }
    });
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final newItems =
          await _mailProvider.getMessagesByLabel(_selectedLabel, pageKey);

      if (_mailProvider.hasNextPage(pageKey) && newItems.isNotEmpty) {
        final nextPageKey = pageKey + 1;
        _pagingController.appendPage(newItems, nextPageKey);
      } else {
        _pagingController.appendLastPage(newItems);
      }

      _addMessagesToPlaylist(newItems);
      // for (var message in playlist) {
      //   debugPrint('Message: ${_mailProvider.getMailTitle(message)}');
      // }
    } catch (error) {
      debugPrint('Error while fetching page: $error');
      _pagingController.error = error;
    }
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
                  : [
                      // build if not empty playlist and signed in
                      Expanded(
                        child: _mailList(),
                      ),
                      _controlsBar(),
                      _progressBar(ttsPausedProgress + ttsProgress),
                    ],
            )),
      ),
    );
  }

  Widget _mailList() {
    return RefreshIndicator(
      onRefresh: () {
        return _refresh();
      },
      child: PagedListView<int, gMail.Message>(
        pagingController: _pagingController,
        builderDelegate: PagedChildBuilderDelegate<gMail.Message>(
          itemBuilder: (context, item, index) {
            return _mailTile(item);
          },
        ),
      ),
    );
  }

  Widget _mailTile(gMail.Message message) {
    return ListTile(
      title: Text(
        _mailProvider.getMailTitle(message),
        style: TextStyle(
            fontSize: 18.0,
            color: ((isPlaying &&
                    (message.hashCode ==
                        playlist[currentPlayingMessageIndex].hashCode))
                ? Colors.blue
                : Colors.black)),
      ),
      subtitle: Text(parseFragment(message.snippet ?? '').text ?? ''),
      // trailing: _playPauseButton(index),
      onTap: () => _mailSelected(message), // Placeholder
      shape: const Border(
        bottom: BorderSide(color: Colors.grey),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      title: const Text('Email Playlist App'),
      backgroundColor: Colors.blue.withOpacity(0.1),
      actions: [
        _labelsBar(),
      ],
    );
  }

  Widget _labelsBar() {
    return Expanded(
      child: FractionallySizedBox(
        alignment: Alignment.centerRight,
        widthFactor: 0.9,
        child: Container(
          padding: const EdgeInsets.all(10),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            scrollDirection: Axis.horizontal,
            separatorBuilder: (BuildContext context, int index) =>
                const Padding(
              padding: EdgeInsets.fromLTRB(3, 0, 3, 0),
            ),
            itemCount: _availableLabels.length,
            itemBuilder: (context, index) {
              return _labelButton(index);
            },
          ),
        ),
      ),
    );
  }

  Widget _labelButton(int index) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: (_selectedLabel == _availableLabels[index].id)
            ? Colors.blue // highlight selected label
            : Colors.white,
      ),
      onPressed: () {
        _labelSelected(_availableLabels[index].id ?? '');
      },
      child: Text(_availableLabels[index].name ?? ''),
    );
  }

  Widget _controlsBar() {
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
                onPressed: () => _playButtonSelected()),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              iconSize: 30,
              onPressed: () => _playNext(),
            ),
          ],
        ));
  }

  Widget _progressBar(int progress) {
    if (playlist.isEmpty ||
        playlist[currentPlayingMessageIndex].snippet == null ||
        playlist[currentPlayingMessageIndex].snippet!.isEmpty) {
      return Container(
        alignment: Alignment.topCenter,
        child: const LinearProgressIndicator(
          value: 0,
        ),
      );
    }

    return Container(
        color: Colors.blue,
        alignment: Alignment.topCenter,
        child: LinearProgressIndicator(
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          value:
              progress / playlist[currentPlayingMessageIndex].snippet!.length,
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
