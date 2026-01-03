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
        textSelectionTheme: const TextSelectionThemeData(cursorColor: Colors.green), // Cursore verde
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
  final List<Track> tracks;

  Playlist({required this.id, required this.name, required this.tracks});

  factory Playlist.fromJson(Map<String, dynamic> json) {
    var list = json['tracks'] as List;
    List<Track> tracksList = list.map((i) => Track.fromJson(i)).toList();
    return Playlist(
      id: json['id'],
      name: json['name'],
      tracks: tracksList,
    );
  }
}

// --- 2. AUDIO MANAGER ---
class AudioManager extends ChangeNotifier {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _player = AudioPlayer();

  List<Track> _queue = [];
  int _currentIndex = -1;
  bool _isLoading = false;

  bool get isPlaying => _player.playing;
  bool get isLoading => _isLoading;
  Track? get currentTrack => (_currentIndex >= 0 && _currentIndex < _queue.length) ? _queue[_currentIndex] : null;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> setQueue(List<Track> tracks, int initialIndex) async {
    _queue = List.from(tracks);
    _currentIndex = initialIndex;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;
    
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
      next();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void togglePlayPause() {
    if (_player.playing) _player.pause(); else _player.play();
    notifyListeners();
  }

  void next() {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _playCurrent();
    }
  }

  void previous() {
    if (_player.position.inSeconds > 3) _player.seek(Duration.zero);
    else if (_currentIndex > 0) {
      _currentIndex--;
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

  // VARIABILI PER LA RICERCA
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  @override
  void initState() {
    super.initState();
    loadPlaylists();
    _audioManager.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) _audioManager.next();
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

  // LOGICA FILTRO PLAYLIST
  List<Playlist> get filteredPlaylists {
    if (_searchText.isEmpty) return playlists;
    return playlists.where((pl) => pl.name.toLowerCase().contains(_searchText.toLowerCase())).toList();
  }

  // LOGICA FILTRO CANZONI
  List<Track> get filteredTracks {
    if (selectedPlaylist == null) return [];
    if (_searchText.isEmpty) return selectedPlaylist!.tracks;
    return selectedPlaylist!.tracks.where((track) {
      return track.name.toLowerCase().contains(_searchText.toLowerCase()) ||
             track.artist.toLowerCase().contains(_searchText.toLowerCase());
    }).toList();
  }

  // GESTIONE ATTIVAZIONE/DISATTIVAZIONE RICERCA
  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

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

    // --- COSTRUIAMO L'APP BAR DINAMICA ---
    AppBar buildAppBar(String title, {VoidCallback? onBack}) {
      return AppBar(
        leading: onBack != null 
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack)
          : (_isSearching ? const Icon(Icons.search) : null), // Se cerco nella home, mostro icona, altrimenti nulla
        title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Cerca...",
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
            )
          : Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: !_isSearching,
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _stopSearch,
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _startSearch,
            ),
        ],
      );
    }

    // VISTA HOME (LISTA PLAYLIST)
    if (selectedPlaylist == null) {
      // Nota: Quando siamo nella Home, resettiamo la ricerca se veniamo da una playlist
      return Scaffold(
        appBar: buildAppBar("Le mie Playlist"),
        body: ListView.builder(
          itemCount: filteredPlaylists.length,
          itemBuilder: (context, index) {
            final pl = filteredPlaylists[index];
            return ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4)),
                child: const Icon(Icons.folder_open, color: Colors.green, size: 30),
              ),
              title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${pl.tracks.length} brani"),
              onTap: () {
                _stopSearch(); // Resetta la ricerca prima di entrare
                setState(() => selectedPlaylist = pl);
              },
            );
          },
        ),
        bottomNavigationBar: const MiniPlayer(),
      );
    }

    // VISTA PLAYLIST (BRANI)
    return Scaffold(
      appBar: buildAppBar(
        selectedPlaylist!.name, 
        onBack: () {
          _stopSearch(); // Resetta la ricerca quando torni indietro
          setState(() => selectedPlaylist = null);
        }
      ),
      body: Column(
        children: [
          // Mostra l'icona grande solo se NON stiamo cercando, per risparmiare spazio
          if (!_isSearching)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: const Icon(Icons.music_note, size: 60, color: Colors.green),
            ),
          
          Expanded(
            child: filteredTracks.isEmpty 
              ? const Center(child: Text("Nessun risultato", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: filteredTracks.length,
                  itemBuilder: (context, index) {
                    final track = filteredTracks[index];
                    final isCurrent = _audioManager.currentTrack == track;
                    
                    return ListTile(
                      leading: Text("${index + 1}", style: const TextStyle(color: Colors.grey, fontSize: 16)),
                      title: Text(track.name, 
                        style: TextStyle(
                          color: isCurrent ? Colors.green : Colors.white, 
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal
                        )
                      ),
                      subtitle: Text(track.artist),
                      trailing: isCurrent && _audioManager.isPlaying 
                        ? const Icon(Icons.volume_up, color: Colors.green, size: 20) 
                        : null,
                      onTap: () {
                        // Se stiamo cercando, la lista è filtrata.
                        // Passiamo al player SOLO la lista filtrata, così "Next" va al prossimo risultato della ricerca
                        _audioManager.setQueue(filteredTracks, index);
                        // Opzionale: Se vuoi chiudere la tastiera dopo il click:
                        FocusScope.of(context).unfocus();
                      },
                    );
                  },
                ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}

// --- 4. MINI PLAYER (Con Timeline Full Width) ---
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
            // APRE LA SCHERMATA GRANDE
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const FullScreenPlayer(),
            );
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            // ClipRRect per tagliare la barra in basso seguendo il bordo
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: const Color(0xFF282828),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ROW CONTENUTO (Con Padding)
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
                          IconButton(
                            icon: const Icon(Icons.skip_previous), 
                            onPressed: manager.previous,
                          ),
                          IconButton(
                            icon: manager.isLoading 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(manager.isPlaying ? Icons.pause : Icons.play_arrow, size: 30),
                            onPressed: manager.togglePlayPause,
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next), 
                            onPressed: manager.next,
                          ),
                        ],
                      ),
                    ),
                    
                    // TIMELINE (Senza Padding = Full Width)
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
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
          ),

          Expanded(
            child: AnimatedBuilder(
              animation: manager,
              builder: (context, child) {
                final track = manager.currentTrack;
                if (track == null) return const SizedBox();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down, size: 30),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Text("IN RIPRODUZIONE", style: TextStyle(fontSize: 10, letterSpacing: 1, color: Colors.grey[400])),
                          const IconButton(icon: Icon(Icons.more_vert), onPressed: null),
                        ],
                      ),
                    ),

                    const Spacer(),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      decoration: BoxDecoration(
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
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

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
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
                      ],
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