
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/data_models.dart';

class AudioManager extends ChangeNotifier {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;

  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _player = AudioPlayer();

  List<Track> _queue = [];
  int _currentIndex = -1;
  bool _isLoading = false;
  LoopModeState _loopMode = LoopModeState.off;

  AudioManager._internal() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handleAutoNext();
      }
    });
  }

  bool get isPlaying => _player.playing;
  bool get isLoading => _isLoading;
  LoopModeState get loopMode => _loopMode;
  Track? get currentTrack => (_currentIndex >= 0 && _currentIndex < _queue.length) ? _queue[_currentIndex] : null;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> setQueue(List<Track> tracks, int initialIndex) async {
    _queue = List.from(tracks);
    _currentIndex = initialIndex;
    await _playCurrent();
  }

  void toggleLoopMode() {
    if (_loopMode == LoopModeState.off) {
      _loopMode = LoopModeState.all;
    } else if (_loopMode == LoopModeState.all) {
      _loopMode = LoopModeState.one;
    } else {
      _loopMode = LoopModeState.off;
    }
    notifyListeners();
  }

  void _handleAutoNext() {
    if (_loopMode == LoopModeState.one) {
      _player.seek(Duration.zero);
      _player.play();
    } else {
      next(automatic: true);
    }
  }

  Future<void> _playCurrent() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;
    
    await _player.stop();
    _isLoading = true;
    notifyListeners();

    try {
      final track = _queue[_currentIndex];
      print("CERCO: ${track.searchQuery}");

      var searchList = await _yt.search.search(track.searchQuery);
      if (searchList.isEmpty) return;
      var video = searchList.first;

      track.runtimeThumbnail = video.thumbnails.highResUrl;

      var manifest = await _yt.videos.streamsClient.getManifest(video.id);
      dynamic streamInfo;
      try {
        var mp4Streams = manifest.muxed.where((s) => s.container.name.toString().toLowerCase().contains('mp4')).toList();
        mp4Streams.sort((a, b) => a.bitrate.compareTo(b.bitrate));
        streamInfo = mp4Streams.isNotEmpty ? mp4Streams.first : manifest.muxed.first;
      } catch (e) {
        streamInfo = manifest.muxed.first;
      }

      await _player.setAudioSource(AudioSource.uri(
        Uri.parse(streamInfo.url.toString()),
        headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36'},
      ));

      _player.play();
    } catch (e) {
      print("Errore: $e");
      next(automatic: true); 
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void togglePlayPause() {
    if (_player.playing) _player.pause(); else _player.play();
    notifyListeners();
  }

  void next({bool automatic = false}) {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _playCurrent();
    } else if (_loopMode == LoopModeState.all) {
      _currentIndex = 0;
      _playCurrent();
    } else {
      if (!automatic) {
         _player.stop();
         _player.seek(Duration.zero);
         notifyListeners();
      }
    }
  }

  void previous() {
    if (_player.position.inSeconds > 3) {
      _player.seek(Duration.zero);
    } else if (_currentIndex > 0) {
      _currentIndex--;
      _playCurrent();
    } else if (_currentIndex == 0 && _loopMode == LoopModeState.all) {
       _currentIndex = _queue.length - 1;
       _playCurrent();
    }
  }

  void seek(Duration position) => _player.seek(position);
  void stop() { _player.stop(); _queue.clear(); _currentIndex = -1; notifyListeners(); }
}
