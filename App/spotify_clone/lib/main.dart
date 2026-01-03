import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spotify Clone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF121212), elevation: 0),
        bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent),
        textSelectionTheme: const TextSelectionThemeData(cursorColor: Colors.green),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Colors.green,
          thumbColor: Colors.green,
          inactiveTrackColor: Colors.grey,
          trackHeight: 4.0,
        ),
      ),
      home: const PlaylistScreen(),
    );
  }
}

// --- ENUM PER GLI STATI DEL LOOP ---
enum LoopModeState { off, all, one }

// --- 1. MODELLI DATI ---
class Track {
  final String name;
  final String artist;
  final String album;
  final String searchQuery;
  String? runtimeThumbnail; 

  Track({
    required this.name,
    required this.artist,
    required this.album,
    required this.searchQuery,
    this.runtimeThumbnail,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      name: json['name'] ?? 'Sconosciuto',
      artist: json['artist'] ?? 'Sconosciuto',
      album: json['album'] ?? '',
      searchQuery: json['search_query'] ?? '',
    );
  }
}

class Playlist {
  final String id;
  final String name;
  final String? imageUrl;
  final List<Track> tracks;

  Playlist({
    required this.id, 
    required this.name, 
    this.imageUrl, 
    required this.tracks
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    var list = json['tracks'] as List;
    List<Track> tracksList = list.map((i) => Track.fromJson(i)).toList();
    
    String? img;
    if (json['image'] != null && json['image'].toString().trim().isNotEmpty) {
      img = json['image'];
    }

    return Playlist(
      id: json['id'].toString(),
      name: json['name'],
      imageUrl: img,
      tracks: tracksList,
    );
  }
}

// --- 2. AUDIO MANAGER (LOGICA LOOP CORRETTA) ---
class AudioManager extends ChangeNotifier {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;

  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _player = AudioPlayer();

  List<Track> _queue = [];
  int _currentIndex = -1;
  bool _isLoading = false;
  LoopModeState _loopMode = LoopModeState.off;

  // COSTRUTTORE
  AudioManager._internal() {
    _player.playerStateStream.listen((state) {
      // INTERCETTA LA FINE DELLA CANZONE
      if (state.processingState == ProcessingState.completed) {
        _handleAutoNext();
      }
    });
  }

  // GETTERS
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

  // LOGICA AUTOMATICA (Quando finisce da sola)
  void _handleAutoNext() {
    print("SONG FINISHED. Loop Mode: $_loopMode");
    
    if (_loopMode == LoopModeState.one) {
      // LOOP 1: Riavvolgi e suona subito (senza ricaricare da internet)
      _player.seek(Duration.zero);
      _player.play();
    } 
    else if (_currentIndex < _queue.length - 1) {
      // C'è una prossima canzone -> Vai avanti
      next(automatic: true);
    } 
    else if (_loopMode == LoopModeState.all) {
      // Fine playlist MA Loop All attivo -> Torna alla prima
      _currentIndex = 0;
      _playCurrent();
    } 
    else {
      // Fine playlist e Loop Off -> STOP e PAUSA
      _player.pause();
      _player.seek(Duration.zero);
      // Importante: notifichiamo la UI che siamo in pausa
      notifyListeners();
    }
  }

  // LOGICA PLAY
  Future<void> _playCurrent() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;
    
    // Ferma il player prima di caricare la nuova (pulisce lo stato)
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
      // Se fallisce, prova la prossima
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

  // NEXT (Manuale)
  void next({bool automatic = false}) {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _playCurrent();
    } else if (_loopMode == LoopModeState.all) {
      // Se clicco Next all'ultima e ho Loop All -> Vado alla prima
      _currentIndex = 0;
      _playCurrent();
    } else {
      // Se clicco Next all'ultima e Loop Off -> Non fare nulla o Stop
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

// --- 3. UI PRINCIPALE ---
class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  List<Playlist> playlists = [];
  final AudioManager _audioManager = AudioManager();
  bool isLoading = true;
  Playlist? selectedPlaylist;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  @override
  void initState() {
    super.initState();
    loadPlaylists();
    
    // Ascolta solo per aggiornare la grafica (Play/Pausa icone)
    _audioManager.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> loadPlaylists() async {
    try {
      final String response = await rootBundle.loadString('assets/music_data.json');
      final data = await json.decode(response) as List;
      setState(() {
        playlists = data.map((e) => Playlist.fromJson(e)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  List<Playlist> get filteredPlaylists {
    if (_searchText.isEmpty) return playlists;
    return playlists.where((pl) => pl.name.toLowerCase().contains(_searchText.toLowerCase())).toList();
  }

  List<Track> get filteredTracks {
    if (selectedPlaylist == null) return [];
    if (_searchText.isEmpty) return selectedPlaylist!.tracks;
    return selectedPlaylist!.tracks.where((track) {
      return track.name.toLowerCase().contains(_searchText.toLowerCase()) ||
             track.artist.toLowerCase().contains(_searchText.toLowerCase());
    }).toList();
  }

  void _startSearch() => setState(() => _isSearching = true);
  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchText = "";
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    AppBar buildAppBar(String title, {VoidCallback? onBack}) {
      return AppBar(
        leading: onBack != null 
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack)
          : (_isSearching ? const Icon(Icons.search) : null),
        title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: "Cerca...", hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
              onChanged: (value) => setState(() => _searchText = value),
            )
          : Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: !_isSearching,
        actions: [
          if (_isSearching)
            IconButton(icon: const Icon(Icons.close), onPressed: _stopSearch)
          else
            IconButton(icon: const Icon(Icons.search), onPressed: _startSearch),
        ],
      );
    }

    if (selectedPlaylist == null) {
      return Scaffold(
        appBar: buildAppBar("Le mie Playlist"),
        body: ListView.builder(
          itemCount: filteredPlaylists.length,
          itemBuilder: (context, index) {
            final pl = filteredPlaylists[index];
            return ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: pl.imageUrl != null 
                  ? Image.network(pl.imageUrl!, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: Colors.grey[800], width: 60, height: 60, child: const Icon(Icons.music_note)))
                  : Container(width: 60, height: 60, color: Colors.grey[800], child: const Icon(Icons.folder_open, color: Colors.green, size: 30)),
              ),
              title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Playlist • ${pl.tracks.length} brani"),
              onTap: () { _stopSearch(); setState(() => selectedPlaylist = pl); },
            );
          },
        ),
        bottomNavigationBar: const MiniPlayer(),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
          child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { _stopSearch(); setState(() => selectedPlaylist = null); }),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            child: IconButton(icon: const Icon(Icons.search), onPressed: _startSearch),
          )
        ],
      ),
      body: Column(
        children: [
          if (!_isSearching)
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.green.withOpacity(0.8), const Color(0xFF121212)])),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 50),
                  Container(
                    decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0,10))]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: selectedPlaylist!.imageUrl != null
                        ? Image.network(selectedPlaylist!.imageUrl!, width: 160, height: 160, fit: BoxFit.cover)
                        : Container(color: Colors.grey[800], width: 160, height: 160, child: const Icon(Icons.music_note, size: 80)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isSearching)
                     const SizedBox()
                  else
                     Text(selectedPlaylist!.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
                ],
              ),
            ),
          
          if (_isSearching) const SizedBox(height: 100),

          Expanded(
            child: Container(
              color: const Color(0xFF121212),
              child: filteredTracks.isEmpty 
                ? const Center(child: Text("Nessun risultato", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: filteredTracks.length,
                    itemBuilder: (context, index) {
                      final track = filteredTracks[index];
                      final isCurrent = _audioManager.currentTrack == track;
                      
                      return ListTile(
                        leading: Text("${index + 1}", style: const TextStyle(color: Colors.grey, fontSize: 16)),
                        title: Text(track.name, style: TextStyle(color: isCurrent ? Colors.green : Colors.white, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(track.artist),
                        trailing: isCurrent && _audioManager.isPlaying ? const Icon(Icons.volume_up, color: Colors.green, size: 20) : null,
                        onTap: () {
                          _audioManager.setQueue(filteredTracks, index);
                          FocusScope.of(context).unfocus();
                        },
                      );
                    },
                  ),
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}

// --- 4. MINI PLAYER ---
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AudioManager(),
      builder: (context, child) {
        final manager = AudioManager();
        final track = manager.currentTrack;

        if (track == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const FullScreenPlayer(),
            );
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: const Color(0xFF282828),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: track.runtimeThumbnail != null 
                              ? Image.network(track.runtimeThumbnail!, width: 45, height: 45, fit: BoxFit.cover)
                              : Container(color: Colors.grey[800], width: 45, height: 45, child: const Icon(Icons.music_note)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(track.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                                Text(track.artist, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.skip_previous), onPressed: manager.previous),
                          IconButton(
                            icon: manager.isLoading 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(manager.isPlaying ? Icons.pause : Icons.play_arrow, size: 30),
                            onPressed: manager.togglePlayPause,
                          ),
                          IconButton(icon: const Icon(Icons.skip_next), onPressed: manager.next),
                        ],
                      ),
                    ),
                    StreamBuilder<Duration>(
                      stream: manager.positionStream,
                      builder: (context, snap) {
                        final pos = snap.data ?? Duration.zero;
                        return StreamBuilder<Duration?>(
                          stream: manager.durationStream,
                          builder: (context, snapDur) {
                             final dur = snapDur.data?.inSeconds.toDouble() ?? 1.0;
                             return LinearProgressIndicator(
                               value: (pos.inSeconds.toDouble() / (dur > 0 ? dur : 1.0)).clamp(0.0, 1.0),
                               backgroundColor: Colors.transparent,
                               valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                               minHeight: 2.0,
                             );
                          }
                        );
                      }
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- 5. SCHERMATA GRANDE ---
class FullScreenPlayer extends StatelessWidget {
  const FullScreenPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = AudioManager();
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      height: screenHeight * 0.92, 
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),

          Expanded(
            child: AnimatedBuilder(
              animation: manager,
              builder: (context, child) {
                final track = manager.currentTrack;
                if (track == null) return const SizedBox();

                IconData loopIcon;
                Color loopColor;
                if (manager.loopMode == LoopModeState.off) {
                  loopIcon = Icons.repeat;
                  loopColor = Colors.grey;
                } else if (manager.loopMode == LoopModeState.all) {
                  loopIcon = Icons.repeat;
                  loopColor = Colors.green;
                } else {
                  loopIcon = Icons.repeat_one;
                  loopColor = Colors.green;
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(icon: const Icon(Icons.keyboard_arrow_down, size: 30), onPressed: () => Navigator.pop(context)),
                          Text("IN RIPRODUZIONE", style: TextStyle(fontSize: 10, letterSpacing: 1, color: Colors.grey[400])),
                          const IconButton(icon: Icon(Icons.more_vert), onPressed: null),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: track.runtimeThumbnail != null
                          ? Image.network(track.runtimeThumbnail!, fit: BoxFit.cover, width: double.infinity, height: 350)
                          : Container(color: Colors.grey[900], height: 350, width: double.infinity, child: const Icon(Icons.music_note, size: 100)),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(track.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            Text(track.artist, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    StreamBuilder<Duration>(
                      stream: manager.positionStream,
                      builder: (context, snapPos) {
                        final pos = snapPos.data ?? Duration.zero;
                        return StreamBuilder<Duration?>(
                          stream: manager.durationStream,
                          builder: (context, snapDur) {
                            final dur = snapDur.data ?? Duration.zero;
                            final max = dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0;
                            final val = pos.inSeconds.toDouble().clamp(0.0, max);
                            
                            return Column(
                              children: [
                                Slider(
                                  value: val, min: 0.0, max: max,
                                  onChanged: (v) => manager.seek(Duration(seconds: v.toInt())),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_format(pos), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                      Text(_format(dur), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                )
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(loopIcon, color: loopColor),
                            onPressed: manager.toggleLoopMode,
                          ),
                          
                          IconButton(icon: const Icon(Icons.skip_previous, size: 45), onPressed: manager.previous),
                          
                          Container(
                            width: 70, height: 70,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: IconButton(
                              icon: manager.isLoading 
                                 ? const CircularProgressIndicator(color: Colors.black)
                                 : Icon(manager.isPlaying ? Icons.pause : Icons.play_arrow, size: 40, color: Colors.black),
                              onPressed: manager.togglePlayPause,
                            ),
                          ),
                          
                          IconButton(icon: const Icon(Icons.skip_next, size: 45), onPressed: manager.next),
                          
                          const IconButton(icon: Icon(Icons.shuffle, color: Colors.grey), onPressed: null),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }
}