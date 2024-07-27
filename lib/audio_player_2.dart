import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsAudioHandler extends BaseAudioHandler {
  final FlutterTts _flutterTts = FlutterTts();
  final List<MediaItem> _playlist = [];
  int _currentIndex = 0;

  TtsAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    _flutterTts.setStartHandler(() {
      playbackState.add(playbackState.value.copyWith(
        controls: [MediaControl.pause],
        playing: true,
      ));
    });

    _flutterTts.setCompletionHandler(() async {
      playbackState.add(playbackState.value.copyWith(
        controls: [MediaControl.play],
        playing: false,
      ));
      await _playNext();
    });

    _flutterTts.setCancelHandler(() {
      playbackState.add(playbackState.value.copyWith(
        controls: [MediaControl.play],
        playing: false,
      ));
    });

    _flutterTts.setPauseHandler(() {
      playbackState.add(playbackState.value.copyWith(
        controls: [MediaControl.play],
        playing: false,
      ));
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint("error: $msg");
    });

    _flutterTts.setProgressHandler(
        (String text, int startOffset, int endOffset, String word) {
      // final newQueue = queue.value;
      // if (newQueue.isEmpty) return;
      // final oldMediaItem = newQueue[_currentIndex];
      // final newMediaItem = oldMediaItem.copyWith(duration: endOffset);
      // newQueue[_currentIndex] = newMediaItem;
      // queue.add(newQueue);
      // mediaItem.add(newMediaItem);
    });
  }

  @override
  Future<void> play() async {
    if (_playlist.isEmpty) return;
    await _flutterTts.speak(_playlist[_currentIndex].extras!['text'] as String);
  }

  @override
  Future<void> pause() async {
    await _flutterTts.pause();
  }

  @override
  Future<void> stop() async {
    await _flutterTts.stop();
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    _playlist.addAll(mediaItems);

    // notify system
    final newQueue = queue.value..addAll(mediaItems);
    queue.add(newQueue);
  }

  Future<void> _playNext() async {
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      await play();
    }
  }

  Future<void> playNext() async {
    await _playNext();
  }

  Future<void> playPrevious() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await play();
    }
  }
}
